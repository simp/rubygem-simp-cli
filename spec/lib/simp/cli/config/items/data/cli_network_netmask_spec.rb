require 'simp/cli/config/items/data/cli_network_netmask'

require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliNetworkNetmask do
  before :each do
    @ci = Simp::Cli::Config::Item::CliNetworkNetmask.new
  end

  describe "#os_value" do
    it "returns the netmask address of a valid interface" do
      allow(Facter).to receive(:value).with('netmask_lo').and_return('255.0.0.0')
      nic = Simp::Cli::Config::Item::CliNetworkInterface.new
      nic.value =  'lo'
      @ci.config_items = { nic.key => nic }
      expect( @ci.os_value ).to eq '255.0.0.0'
    end

    it "returns nil for an invalid interface" do
      nic = Simp::Cli::Config::Item::CliNetworkInterface.new
      nic.value =  'eth_oops'
      @ci.config_items = { nic.key => nic }
      expect( @ci.os_value ).to be_nil
      # TODO: verify only print outs 1 warning when called more than once
      expect( @ci.os_value ).to be_nil
    end
  end

  describe "#validate" do
    it "validates netmasks" do
      expect( @ci.validate '255.255.255.0' ).to eq true
      expect( @ci.validate '255.254.0.0' ).to eq true
      expect( @ci.validate '192.0.0.0' ).to eq true
    end

    it "doesn't validate bad netmasks" do
      expect( @ci.validate '999.999.999.999' ).to eq false
      expect( @ci.validate '255.999.0.0' ).to eq false
      expect( @ci.validate '255.0.255.0' ).to eq false
      expect( @ci.validate '0.255.0.0' ).to eq false
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate false ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
