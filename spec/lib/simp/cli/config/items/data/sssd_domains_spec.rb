require 'simp/cli/config/items/data/sssd_domains'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SssdDomains do
  before :each do
    @ci = Simp::Cli::Config::Item::SssdDomains.new
    @ci.silent = true
  end

  describe '#recommended_value' do

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
        it "should return ['LOCAL']" do
          os_fact = { 'release' => { 'major' => '7' } }
          allow(Facter).to receive(:value).with('os').and_return(os_fact)

          item = Simp::Cli::Config::Item::SimpOptionsLdap.new
          item.value = false
          @ci.config_items[item.key] = item
          expect( @ci.recommended_value ).to eq ['LOCAL']
        end
      end

      context 'OS major version >= 8' do
        it "should return []" do
          os_fact = { 'release' => { 'major' => '8' } }
          allow(Facter).to receive(:value).with('os').and_return(os_fact)

          item = Simp::Cli::Config::Item::SimpOptionsLdap.new
          item.value = false
          @ci.config_items[item.key] = item
          expect( @ci.recommended_value ).to eq []
        end
      end
    end

  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
