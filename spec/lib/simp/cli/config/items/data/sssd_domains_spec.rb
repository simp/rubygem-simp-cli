require 'simp/cli/config/items/data/sssd_domains'
require 'simp/cli/config/items/data/simp_options_ldap'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SssdDomains do
  before :each do
    @ci = Simp::Cli::Config::Item::SssdDomains.new
    @ci.silent = true
  end

  describe "#recommended_value" do
    it "when `simp_options::ldap` is `true`" do
      item = Simp::Cli::Config::Item::SimpOptionsLdap.new
      item.value = true
      @ci.config_items[item.key] = item
      expect( @ci.recommended_value ).to eq ['LDAP']
    end

    it "when `simp_options::ldap` is `false`" do
      item = Simp::Cli::Config::Item::SimpOptionsLdap.new
      item.value = false
      @ci.config_items[item.key] = item
      expect( @ci.recommended_value ).to eq ['Local']
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
