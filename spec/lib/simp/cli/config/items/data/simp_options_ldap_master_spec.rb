# frozen_string_literal: true

require 'simp/cli/config/items/data/simp_options_ldap_master'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsLdapMaster do
  before :each do
    @ci = described_class.new
  end

  describe '#recommended_value' do
    context 'when LDAP server is not defined' do
      it 'sets master to FIXME' do
        expect(@ci.recommended_value).to eq 'ldap://FIXME'
      end
    end

    context 'when is LDAP server and cli::network::hostname defined' do
      it 'sets master to SIMP server' do
        item = Simp::Cli::Config::Item::CliIsSimpLdapServer.new
        item.value = true
        @ci.config_items[item.key] = item
        item = Simp::Cli::Config::Item::CliNetworkHostname.new
        item.value = 'server1.test.local'
        @ci.config_items[item.key] = item

        expect(@ci.recommended_value).to eq 'ldap://server1.test.local'
      end
    end

    context 'when is LDAP server and cli::network::hostname is not defined' do
      it 'sets master to FIXME' do
        item = Simp::Cli::Config::Item::CliIsSimpLdapServer.new
        item.value = true
        @ci.config_items[item.key] = item

        expect(@ci.recommended_value).to eq 'ldap://FIXME'
      end
    end

    context 'when is not LDAP server and cli::network::hostname defined' do
      it 'sets master to FIXME' do
        item = Simp::Cli::Config::Item::CliIsSimpLdapServer.new
        item.value = false
        @ci.config_items[item.key] = item
        item = Simp::Cli::Config::Item::CliNetworkHostname.new
        item.value = 'server1.test.local'
        @ci.config_items[item.key] = item

        expect(@ci.recommended_value).to eq 'ldap://FIXME'
      end
    end
  end

  describe '#validate' do
    it 'validates good ldap uri' do
      expect(@ci.validate('ldap://master')).to be true
      expect(@ci.validate('ldaps://master-server')).to be true
      expect(@ci.validate('ldap://master.ldap.org')).to be true
      expect(@ci.validate('ldaps://192.168.1.1')).to be true
    end

    it "doesn't validate bad ldap uri" do
      expect(@ci.validate(nil)).to be false
      expect(@ci.validate('')).to    be false
      expect(@ci.validate('   ')).to be false
      expect(@ci.validate(false)).to be false
      expect(@ci.validate([nil])).to be false
      expect(@ci.validate('master')).to be false
      expect(@ci.validate('ldap://master-')).to be false
      expect(@ci.validate('ldap://-master')).to be false
      expect(@ci.validate('ldap://master.loggitylog.org-')).to be false
      expect(@ci.validate('ldap://.master.loggitylog.org')).to be false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
