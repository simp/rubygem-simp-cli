require 'simp/cli/config/items/data/sssd_domains'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SssdDomains do
  describe '#recommended_value' do
    before :each do
      @ci = Simp::Cli::Config::Item::SssdDomains.new
      @ci.silent = true
    end

    context "when 'simp_options::ldap' is 'true'" do
      it "should return ['LDAP']" do
        item = Simp::Cli::Config::Item::SimpOptionsLdap.new
          item.value = true
        @ci.config_items[item.key] = item
        expect( @ci.recommended_value ).to eq ['LDAP']
      end
    end

    context "when 'simp_options::ldap' is 'false'" do
      context 'OS major version < 8' do
        before :each do
          os_fact = { 'release' => { 'major' => '7' } }
          allow(Facter).to receive(:value).with('os').and_return(os_fact)

          item = Simp::Cli::Config::Item::SimpOptionsLdap.new
          item.value = false
          @ci.config_items[item.key] = item
        end

        it "should return ['LOCAL']" do
          expect( @ci.recommended_value ).to eq ['LOCAL']
        end
      end

      context 'OS major version >= 8' do
        before :each do
          os_fact = { 'release' => { 'major' => '8' } }
          allow(Facter).to receive(:value).with('os').and_return(os_fact)

          item = Simp::Cli::Config::Item::SimpOptionsLdap.new
          item.value = false
          @ci.config_items[item.key] = item
        end

        it 'should return []' do
          expect( @ci.recommended_value ).to eq []
        end
      end
    end
  end

  describe '#validate' do
    context 'OS major version < 8' do
      before :each do
        os_fact = { 'release' => { 'major' => '7' } }
        allow(Facter).to receive(:value).with('os').and_return(os_fact)

        @ci = Simp::Cli::Config::Item::SssdDomains.new
        @ci.silent = true
        item = Simp::Cli::Config::Item::SimpOptionsLdap.new
        item.value = false
        @ci.config_items[item.key] = item
      end

      it 'should reject an empty domain list' do
        expect( @ci.validate([]) ).to eq false
      end
    end

    context 'OS major version >= 8' do
      before :each do
        os_fact = { 'release' => { 'major' => '8' } }
        allow(Facter).to receive(:value).with('os').and_return(os_fact)

        @ci = Simp::Cli::Config::Item::SssdDomains.new
        @ci.silent = true
        item = Simp::Cli::Config::Item::SimpOptionsLdap.new
        item.value = false
        @ci.config_items[item.key] = item
      end

      it 'should accept an empty domain list' do
        expect( @ci.validate([]) ).to eq true
      end
    end
  end

  context 'base operation' do
    before :each do
      @ci = Simp::Cli::Config::Item::SssdDomains.new
      @ci.silent = true
    end

    it_behaves_like "a child of Simp::Cli::Config::Item"
  end
end
