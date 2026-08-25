# frozen_string_literal: true

require 'simp/cli/config/items/data/simp_sssd_client_ldap_server_type'
# require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpSssdClientLdapServerType do
  before :each do
    @ci = described_class.new
    @ci.silent = true
  end

  describe '#recommended_value' do
    context 'OS major version < 8' do
      before :each do
        os_fact = { 'release' => { 'major' => '7' } }
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
      end

      it "returns 'plain'" do
        expect(@ci.recommended_value).to eq 'plain'
      end
    end

    context 'OS major version >= 8' do
      before :each do
        os_fact = { 'release' => { 'major' => '8' } }
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
      end

      it "returns '389ds'" do
        expect(@ci.recommended_value).to eq '389ds'
      end
    end
  end

  describe '#validate' do
    it "accepts '389ds'" do
      expect(@ci.validate('389ds')).to be true
    end

    it "accepts 'plain'" do
      expect(@ci.validate('plain')).to be true
    end

    it 'rejects an empty type' do
      expect(@ci.validate('')).to be false
    end

    it 'rejects an unsupported type' do
      expect(@ci.validate('ad')).to be false
    end
  end

  context 'base operation' do
    it_behaves_like 'a child of Simp::Cli::Config::Item'
  end
end
