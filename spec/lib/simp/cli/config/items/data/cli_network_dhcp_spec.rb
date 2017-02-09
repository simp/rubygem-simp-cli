require 'simp/cli/config/items/data/cli_network_dhcp'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliNetworkDHCP do
  before :each do
    @ci = Simp::Cli::Config::Item::CliNetworkDHCP.new
  end

  describe "#validate" do
    it "validates dhcp/static" do
      expect( @ci.validate('dhcp') ).to eq true
      expect( @ci.validate('DHCP') ).to eq true
      expect( @ci.validate('static') ).to eq true
      expect( @ci.validate('STATIC') ).to eq true
    end

    it "doesn't validate other things" do
      expect( @ci.validate 'oops' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"

end
