require 'simp/cli/config/items/data/simp_options_ldap_bind_hash'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsLdapBindHash do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsLdapBindHash.new
  end

  describe "#encrypt" do
    it "encrypts a known password and salt to the correct SHA-1 password" do
      expect( @ci.encrypt( 'foo', "\xef\xb2\x2e\xac" ) ).to eq '{SSHA}zxOLQEdncCJTMObl5s+y1N/Ydh3vsi6s'
    end
  end

  describe "#validate" do
    it "validates OpenLDAP-format SHA-1 algorithm (FIPS 160-1) password hash" do
      expect( @ci.validate '{SSHA}Y6x92VpatHf9G6yMiktUYTrA/3SxUFm' ).to eq true
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
