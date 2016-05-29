require 'spec_helper'

describe Stokla do
  it 'has a version number' do
    expect(Stokla::VERSION).not_to be nil
  end

  describe "#configure" do
    let(:options){ { schema: 'public', table_name: 'jobs' }}

    subject { Stokla.configure(options) }
    it 'should set attributes' do
      subject 

      expect(Stokla.schema).to eq("public")
      expect(Stokla.table_name).to eq("jobs")
    end
  end

  describe "pool" do
    it "raises with unsupported pool type" do
      expect do
        original, ENV['RACK_ENV'] = ENV['RACK_ENV'], 'production'
        Stokla.pool = "test"
      end.to raise_error(/Usupported pool type: test/)
      ENV['RACK_ENV'] = 'test'
    end
  end

  describe "#logger" do
    it "creates by default" do
      expect(Stokla.logger).not_to be_nil
    end
  end

  describe "#pool" do    
    it 'gets' do
      conn = double
      Stokla.pool = double(checkout: conn)
      
      Stokla.pool.checkout do |c|
        expect(c).to eq(conn)
      end
    end
  end
end
