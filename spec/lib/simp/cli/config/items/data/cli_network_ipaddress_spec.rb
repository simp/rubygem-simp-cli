require 'simp/cli/config/items/data/cli_network_ipaddress'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliNetworkIPAddress do
  before :each do
    @ci = Simp::Cli::Config::Item::CliNetworkIPAddress.new
  end

  describe "#os_value" do
    it "returns the ip address of a valid interface" do
      allow(Facter).to receive(:value).with('ipaddress_lo').and_return('127.0.0.1')
      nic = Simp::Cli::Config::Item::CliNetworkInterface.new
      nic.value =  'lo'
      @ci.config_items = { nic.key => nic }
      expect( @ci.os_value ).to eq '127.0.0.1'
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
    it "validates IPv4 IPs" do
      expect( @ci.validate '192.168.1.1' ).to eq true
    end

    it "doesn't validate bad IPs" do
      expect( @ci.validate 'x.x.x.x' ).to eq false
      expect( @ci.validate '999.999.999.999' ).to eq false
      expect( @ci.validate '192.168.1.1/24' ).to eq false
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate false ).to eq false
    end
  end
  it_behaves_like "a child of Simp::Cli::Config::Item"
end
