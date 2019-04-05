require 'simp/cli/config/items/data/simp_options_ldap_uri'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsLdapUri do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsLdapUri.new
  end

  describe '#recommended_value' do
    context 'when is LDAP server and cli::network::hostname defined' do
      it 'sets URI list to SIMP server' do
        item = Simp::Cli::Config::Item::CliIsSimpLdapServer.new
        item.value = true
        @ci.config_items[item.key] = item
        item = Simp::Cli::Config::Item::CliNetworkHostname.new
        item.value = 'server1.test.local'
        @ci.config_items[item.key] = item

        expect( @ci.recommended_value ).to eq ['ldap://server1.test.local']
      end
    end

    context 'when is LDAP server and cli::network::hostname is not defined' do
      it 'sets URI list to FIXME' do
        item = Simp::Cli::Config::Item::CliIsSimpLdapServer.new
        item.value = true
        @ci.config_items[item.key] = item

        expect( @ci.recommended_value ).to eq [ 'ldap://FIXME' ]
      end
    end

    context 'when is not LDAP server and cli::network::hostname defined' do
      it 'sets URI list to FIXME' do
        item = Simp::Cli::Config::Item::CliIsSimpLdapServer.new
        item.value = false
        @ci.config_items[item.key] = item
        item = Simp::Cli::Config::Item::CliNetworkHostname.new
        item.value = 'server1.test.local'
        @ci.config_items[item.key] = item

        expect( @ci.recommended_value ).to eq [ 'ldap://FIXME' ]
      end
    end
  end

  describe '#validate' do
    it 'validates array with good hosts' do
      expect( @ci.validate ['ldap://log'] ).to eq true
      expect( @ci.validate ['ldaps://log-server'] ).to eq true
      expect( @ci.validate ['ldap://log.loggitylog.org'] ).to eq true
      expect( @ci.validate ['ldaps://192.168.1.1'] ).to eq true
      expect( @ci.validate ['ldap://192.168.1.1', 'ldap://log.loggitylog.org'] ).to eq true
    end

    it "doesn't validate array with bad hosts" do
      expect( @ci.validate 0     ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate [nil] ).to eq false
      expect( @ci.validate ['log-'] ).to eq false
      expect( @ci.validate ['-log'] ).to eq false
      expect( @ci.validate ['log.loggitylog.org.'] ).to eq false
      expect( @ci.validate ['.log.loggitylog.org'] ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end

