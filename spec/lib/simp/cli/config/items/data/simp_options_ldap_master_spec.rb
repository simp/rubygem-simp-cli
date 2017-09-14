require 'simp/cli/config/items/data/simp_options_ldap_master'
require 'simp/cli/config/items/data/cli_is_ldap_server'
require 'simp/cli/config/items/data/cli_network_hostname'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsLdapMaster do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsLdapMaster.new
  end

  describe '#recommended_value' do
    context 'when LDAP server is not defined' do
      it 'sets master to FIXME' do
        expect( @ci.recommended_value ).to eq 'ldap://FIXME'
      end
    end

    context 'when is LDAP server and cli::network::hostname defined' do
      it 'sets master to SIMP server' do
        item = Simp::Cli::Config::Item::CliIsLdapServer.new
        item.value = true
        @ci.config_items[item.key] = item
        item = Simp::Cli::Config::Item::CliNetworkHostname.new
        item.value = 'server1.test.local'
        @ci.config_items[item.key] = item

        expect( @ci.recommended_value ).to eq 'ldap://server1.test.local'
      end
    end

    context 'when is LDAP server and cli::network::hostname is not defined' do
      it 'sets master to FIXME' do
        item = Simp::Cli::Config::Item::CliIsLdapServer.new
        item.value = true
        @ci.config_items[item.key] = item

        expect( @ci.recommended_value ).to eq 'ldap://FIXME'
      end
    end

    context 'when is not LDAP server and cli::network::hostname defined' do
      it 'sets master to FIXME' do
        item = Simp::Cli::Config::Item::CliIsLdapServer.new
        item.value = false
        @ci.config_items[item.key] = item
        item = Simp::Cli::Config::Item::CliNetworkHostname.new
        item.value = 'server1.test.local'
        @ci.config_items[item.key] = item

        expect( @ci.recommended_value ).to eq 'ldap://FIXME'
      end
    end
  end

  describe '#validate' do
    it 'validates good ldap uri' do
      expect( @ci.validate 'ldap://master' ).to eq true
      expect( @ci.validate 'ldaps://master-server' ).to eq true
      expect( @ci.validate 'ldap://master.ldap.org' ).to eq true
      expect( @ci.validate 'ldaps://192.168.1.1' ).to eq true
    end

    it "doesn't validate bad ldap uri" do
      expect( @ci.validate nil   ).to eq false
      expect( @ci.validate '' ).to    eq false
      expect( @ci.validate '   ' ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate [nil] ).to eq false
      expect( @ci.validate 'master' ).to eq false
      expect( @ci.validate 'ldap://master-' ).to eq false
      expect( @ci.validate 'ldap://-master' ).to eq false
      expect( @ci.validate 'ldap://master.loggitylog.org-' ).to eq false
      expect( @ci.validate 'ldap://.master.loggitylog.org' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end

