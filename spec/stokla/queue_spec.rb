require 'spec_helper'
require 'pg'

module Stokla
  describe Queue do
    let(:queue){ Queue.new(qname) }
    let(:qname){ 'queue' }
    let(:conn){ instance_double(PG::Connection, finished?: true) }
    let(:result) { instance_double(PG::Result, values: []) }

    before {
      Stokla.pool = double(checkout: conn, get: conn)
      allow(PG).to receive(:connect).and_return(conn)
      allow(conn).to receive(:quote_ident) { |sql| sql }
      allow(conn).to receive(:exec_params) { |sql, *params| result }
    }

    describe "#take" do
      it 'returns nil without jobs' do
        allow(queue).to receive(:locking_take)

        expect(queue.take).to be_nil
      end

      context "with db locks" do
        it 'locks item' do
          item = double
          allow(queue).to receive(:locking_take).and_return(item)

          expect(queue.take).to eq(item)
          expect(queue).not_to receive(:delete)
        end

        it 'unlocks with block' do
          item = double
          allow(queue).to receive(:locking_take).and_return(item)
          expect(queue).to receive(:delete).with(item)

          queue.take do |_item|
            expect(_item).to eq(item)
          end
        end
      end

      context 'with exception' do
        it 'unlocks item' do
          item = double(item: double(id: 1))
          allow(queue).to receive(:locking_take).and_return(item)

          expect(queue).to receive(:unlock_item).with(item)
          expect(Stokla.logger).to receive(:warn)

          queue.take { raise "BOOM" }
        end
      end
    end

    describe "#delete" do
      let(:locking_item){ LockedItem.new(double(id: 100), [101, 100]) }
      subject { queue.delete(locking_item) }

      before { queue.send(:add_thread_lock, 100, 101) }

      it "marks item as deleted" do
        expect(queue).to receive(:execute).twice do |sql, *params|
          if sql =~ /UPDATE/
            expect(params).to eq([100])
          end

          if sql =~ /pg_advisory_unlock/
            expect(params).to eq([101, 100, { connection: conn }])
          end
        end

        subject
      end

      it "deletes item" do
        original, Stokla.delete_after_completion = Stokla.delete_after_completion, true

        expect(queue).to receive(:execute).twice do |sql, *params|
          expect(sql).to match(/(DELETE FROM|pg_advisory_unlock)/)
          expect(params).to eq([100]) if sql =~ /DELETE/
        end

        subject

        Stokla.delete_after_completion = original
      end
    end

    describe "#enqueue" do
      subject { queue.enqueue(item, 2) }
      let(:item) { { work: 'foobar' }}

      it "inserts" do
        expect(queue).to receive(:execute).exactly(3).times do |sql, *params|
          if sql =~ /INSERT/
            expect(params[0]).to eq(qname)
            expect(params[1]).to eq(item.to_yaml)
            expect(params[2]).to eq(2)
          end
          result
        end

        subject
      end
    end
  end
end