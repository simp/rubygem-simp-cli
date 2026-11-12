# frozen_string_literal: true

require 'simp/cli/config/items/data/sssd_domains_entries'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SssdDomainsEntries do
  before :each do
    @ci = described_class.new
    @ci.silent = true
  end

  it "uses the 'sssd::domains_entries' key" do
    expect(@ci.key).to eq 'sssd::domains_entries'
  end

  describe '#recommended_value' do
    context "when 'simp_options::ldap' is 'true'" do
      it "returns { 'LDAP' => {} }" do
        item = Simp::Cli::Config::Item::SimpOptionsLdap.new
        item.value = true
        @ci.config_items[item.key] = item
        expect(@ci.recommended_value).to eq('LDAP' => {})
      end
    end

    context "when 'simp_options::ldap' is 'false'" do
      before :each do
        item = Simp::Cli::Config::Item::SimpOptionsLdap.new
        item.value = false
        @ci.config_items[item.key] = item
      end

      it 'returns {}' do
        expect(@ci.recommended_value).to eq({})
      end
    end
  end

  describe '#validate' do
    it 'accepts a Hash' do
      expect(@ci.validate('LDAP' => {})).to be true
      expect(@ci.validate({})).to be true
    end

    it 'rejects an Array' do
      expect(@ci.validate(['LDAP'])).to be false
    end
  end

  describe '#to_yaml_s' do
    it 'writes a Hash of domains as a Hash' do
      @ci.value = { 'LDAP' => {} }
      expect(@ci.to_yaml_s).to include("sssd::domains_entries:\n  LDAP: {}")
    end

    it 'writes nothing when there are no domains' do
      @ci.value = {}
      expect(@ci.to_yaml_s).to be_nil
    end
  end

  context 'base operation' do
    it_behaves_like 'a child of Simp::Cli::Config::Item'
  end
end
