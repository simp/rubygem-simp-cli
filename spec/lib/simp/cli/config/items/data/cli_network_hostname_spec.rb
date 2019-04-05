require 'simp/cli/config/items/data/cli_network_hostname'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliNetworkHostname do
  before :each do
    @ci = Simp::Cli::Config::Item::CliNetworkHostname.new
  end

  describe '#get_recommended_value' do
    it 'returns valid hostname when only one is found by hostname -A' do
      allow(@ci).to receive(:`).with('hostname -A 2>/dev/null').and_return("host.test.local\n")
      expect( @ci.get_recommended_value ).to eq 'host.test.local'
    end

    it 'returns first valid hostname when more than one is found by hostname -A' do
      allow(@ci).to receive(:`).with('hostname -A 2>/dev/null').and_return("host.test.local host2.test.local\n")
      expect( @ci.get_recommended_value ).to eq 'host.test.local'
    end

    it 'returns valid hostname from fqdn fact when hostname -A is empty' do
      allow(@ci).to receive(:`).with('hostname -A 2>/dev/null').and_return('')
      allow(Facter).to receive(:value).with('fqdn').and_return('host.test.local')
      expect( @ci.get_recommended_value ).to eq 'host.test.local'
    end

    it 'returns puppet.change.me when fqdn fact returns nil' do
      allow(@ci).to receive(:`).with('hostname -A 2>/dev/null').and_return('')
      allow(Facter).to receive(:value).with('fqdn').and_return(nil)
      expect( @ci.get_recommended_value ).to eq 'puppet.change.me'
    end

    it 'returns puppet.change.me when fqdn fact returns an invalid value' do
      allow(@ci).to receive(:`).with('hostname -A 2>/dev/null').and_return('')
      allow(Facter).to receive(:value).with('fqdn').and_return('localhost')
      expect( @ci.get_recommended_value ).to eq 'puppet.change.me'
    end
  end

  describe '#validate' do
    it 'validates fqdns' do
      expect( @ci.validate 'puppet.change.me' ).to eq true
    end

    it "doesn't validate bad fqdns" do
      expect( @ci.validate '.puppet' ).to eq false
      expect( @ci.validate 'puppet-' ).to eq false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
