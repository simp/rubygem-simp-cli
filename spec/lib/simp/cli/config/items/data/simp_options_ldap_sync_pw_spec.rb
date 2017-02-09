require 'simp/cli/config/items/data/simp_options_ldap_sync_pw'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsLdapSyncPw do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsLdapSyncPw.new
    @ci.silent = true
  end

  describe "#validate" do
    it "validates valid password" do
      expect( @ci.validate 'a!S@d3F$g5H^j&k' ).to eq true
    end

    it "doesn't validate empty passwords" do
      expect( @ci.validate '' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
