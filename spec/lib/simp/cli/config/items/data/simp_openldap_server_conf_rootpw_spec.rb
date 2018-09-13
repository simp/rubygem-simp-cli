require 'simp/cli/config/items/data/simp_openldap_server_conf_rootpw'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOpenldapServerConfRootpw do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOpenldapServerConfRootpw.new
  end

  describe '#encrypt' do
    it 'encrypts a known password and salt to the correct SHA-1 password' do
      expect( @ci.encrypt( 'foo', "\xef\xb2\x2e\xac" ) ).to eq '{SSHA}zxOLQEdncCJTMObl5s+y1N/Ydh3vsi6s'
    end
  end

  describe '#validate' do
    it 'validates a password' do
      # make sure value is not preset to validate an unencrypted password
      @ci.value = nil
      expect( @ci.validate 'Y6x92VpatHf9G6yMiktUYTrA/3SxUFm' ).to eq true
    end

    it 'validates OpenLDAP-format SHA-1 algorithm (FIPS 160-1) password hash' do
      # make sure value is preset to validate an encrypted password
      @ci.value = '{SSHA}Y6x92VpatHf9G6yMiktUYTrA/3SxUFm'
      expect( @ci.validate '{SSHA}Y6x92VpatHf9G6yMiktUYTrA/3SxUFm' ).to eq true
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
