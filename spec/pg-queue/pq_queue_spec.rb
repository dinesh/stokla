require 'spec_helper'

describe Stokla do
  it 'has a version number' do
    expect(Stokla::VERSION).not_to be nil
  end

  describe "#configure" do
    let(:options){ { dbname: 'test', port: 500}}

    subject { Stokla.configure(options) }
    it 'should set attributes' do
      subject 

      expect(Stokla.dbname).to eq("test")
      expect(Stokla.port).to eq(500)
    end
  end

  describe "#logger" do
    it "creates by default" do
      expect(Stokla.logger).not_to be_nil
    end
  end

  describe "#pool" do
    after { Stokla.instance_variable_set(:"@pool", nil) }
    
    it 'gets' do
      conn = double
      allow(PG).to receive(:connect).and_return(conn)

      Stokla.pool.checkout do |c|
        expect(c).to eq(conn)
      end
    end
  end
end
