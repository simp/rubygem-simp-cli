require 'simp/cli/config/items/data/simp_sssd_client_ldap_server_type'
#require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpSssdClientLdapServerType do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpSssdClientLdapServerType.new
    @ci.silent = true
  end

  describe '#recommended_value' do
    context 'OS major version < 8' do
      before :each do
        os_fact = { 'release' => { 'major' => '7' } }
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
      end

      it "should return 'plain'" do
        expect( @ci.recommended_value ).to eq 'plain'
      end
    end

    context 'OS major version >= 8' do
      before :each do
        os_fact = { 'release' => { 'major' => '8' } }
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
      end

      it "should return '389ds'" do
        expect( @ci.recommended_value ).to eq '389ds'
      end
    end
  end

  describe '#validate' do
    it "should accept '389ds'" do
      expect( @ci.validate('389ds') ).to eq true
    end

    it "should accept 'plain'" do
      expect( @ci.validate('plain') ).to eq true
    end

    it 'should reject an empty type' do
      expect( @ci.validate('') ).to eq false
    end

    it 'should reject an unsupported type' do
      expect( @ci.validate('ad') ).to eq false
    end
  end

  context 'base operation' do
    it_behaves_like "a child of Simp::Cli::Config::Item"
  end
end
