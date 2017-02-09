require 'simp/cli/config/items/data/simp_yum_os_update_url'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpYumOsUpdateUrl do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpYumOsUpdateUrl.new
  end

  describe '#validate' do
    it 'validates http/https uris' do
      expect( @ci.validate 'http://mirror.centos.org/centos/7/os/x86_64' ).to eq true
      expect( @ci.validate 'https://some/path' ).to eq true
    end

    it "doesn't validate non-http uris" do
      expect( @ci.validate nil   ).to eq false
      expect( @ci.validate '' ).to    eq false
      expect( @ci.validate '   ' ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate 'ldap://master' ).to eq false
      expect( @ci.validate 'ldaps://master' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end

