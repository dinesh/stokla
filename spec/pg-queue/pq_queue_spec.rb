require 'spec_helper'

describe PGQueue do
  it 'has a version number' do
    expect(PGQueue::VERSION).not_to be nil
  end

  describe "#configure" do
    let(:options){ { dbname: 'test', port: 500}}

    subject { PGQueue.configure(options) }
    it 'should set attributes' do
      subject 

      expect(PGQueue.dbname).to eq("test")
      expect(PGQueue.port).to eq(500)
    end
  end

  describe "#logger" do
    it "creates by default" do
      expect(PGQueue.logger).not_to be_nil
    end
  end

  describe "#pool" do
    after { PGQueue.instance_variable_set(:"@pool", nil) }
    
    it 'gets' do
      conn = double
      allow(PG).to receive(:connect).and_return(conn)

      PGQueue.pool.checkout do |c|
        expect(c).to eq(conn)
      end
    end
  end
end
