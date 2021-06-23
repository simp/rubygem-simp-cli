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
      before :each do
        item = Simp::Cli::Config::Item::SimpOptionsLdap.new
        item.value = false
        @ci.config_items[item.key] = item
      end

      it "should return []" do
        expect( @ci.recommended_value ).to eq []
      end
    end

  end

  describe '#validate' do
    context 'It should accept emtpy lists' do
      before :each do
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
