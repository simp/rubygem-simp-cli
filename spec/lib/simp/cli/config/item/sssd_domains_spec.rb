require 'simp/cli/config/item/sssd_domains'
require 'simp/cli/config/item/use_ldap'
require 'rspec/its'
require_relative 'spec_helper'

describe Simp::Cli::Config::Item::SssdDomains do
  before :each do
    @ci = Simp::Cli::Config::Item::SssdDomains.new
    @ci.silent = true
  end

  describe "#value" do
    it "when `use_fqdn` is `true`" do
      item = Simp::Cli::Config::Item::UseLdap.new
      item.value = true
      @ci.config_items[item.key] = item
      @ci.query
      expect( @ci.value ).to eq ['LDAP']
    end

    it "when `use_fqdn` is `false`" do
      item = Simp::Cli::Config::Item::UseLdap.new
      item.value = false
      @ci.config_items[item.key] = item
      @ci.query
      expect( @ci.value ).to eq []
    end
  end

  describe "#to_yaml_s" do
    it "when `use_fqdn` is `true`" do
      item = Simp::Cli::Config::Item::UseLdap.new
      item.value = true
      @ci.config_items[item.key] = item
      @ci.query
      expect( @ci.to_yaml_s ).to match( %r{^"?sssd::domains"?} )
    end

    it "when `use_fqdn` is `false`" do
      item = Simp::Cli::Config::Item::UseLdap.new
      item.value = false
      @ci.config_items[item.key] = item
      @ci.query
      expect( @ci.to_yaml_s ).to match( %r{^#(#| )*"?sssd::domains"?} )
    end
  end
  it_behaves_like "a child of Simp::Cli::Config::Item"
end
