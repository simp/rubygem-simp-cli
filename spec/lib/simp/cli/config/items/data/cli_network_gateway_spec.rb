require 'simp/cli/config/items/data/cli_network_gateway'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliNetworkGateway do
  before :each do
    @ci = Simp::Cli::Config::Item::CliNetworkGateway.new
  end

  describe "#validate" do
    it "validates plausible gateways" do
      expect( @ci.validate '192.168.1.0' ).to eq true
    end

    it "doesn't validate impossible gateways" do
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate '999.999.999.999' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
