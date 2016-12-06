require 'simp/cli/config/items/data/simp_options_ldap_root_dn'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsLdapRootDn do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsLdapRootDn.new
  end

  describe '#os_value' do
    it 'returns no OS value when cli::is_ldap_server is not present' do
      expect( @ci.os_value ).to be_nil
    end

    it 'returns no OS value when cli::is_ldap_server is false' do
      item = Simp::Cli::Config::Item::CliIsLdapServer.new
      item.value = false
      @ci.config_items[item.key] = item
      expect( @ci.os_value ).to be_nil
    end

    context 'when cli::is_ldap_server is true' do
      pending 'returns rootdn from existing /etc/openldap/sldapd.conf'
      pending 'returns nil when that /etc/openldap/sldapd.conf does not exist'
    end
  end

  describe '#recommended_value' do
    it 'returns no value when cli::is_ldap_server is not present' do
      expect( @ci.recommended_value ).to be_nil
    end

    it 'returns no value when cli::is_ldap_server is false' do
      item = Simp::Cli::Config::Item::CliIsLdapServer.new
      item.value = false
      @ci.config_items[item.key] = item
      expect( @ci.recommended_value ).to be_nil
    end

    it 'returns hiera-based value when cli::is_ldap_server is true' do
      item = Simp::Cli::Config::Item::CliIsLdapServer.new
      item.value = true
      @ci.config_items[item.key] = item
      expect( @ci.recommended_value ).to eq "cn=LDAPAdmin,ou=People,%{hiera('simp_options::ldap::base_dn')}"
    end
  end

  describe "#validate" do
    it "validates ldap_root_dns" do
      expect( @ci.validate 'cn=hostAuth,ou=Hosts,dc=tasty,dc=bacon' ).to eq true
    end

    it "doesn't validate bad ldap_root_dns" do
      expect( @ci.validate 'dc=tasty,dc=bacon' ).to eq false
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate false ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
