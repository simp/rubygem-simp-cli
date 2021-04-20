require 'simp/cli/config/items/data/cli_local_priv_user'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliLocalPrivUser do
  before :each do
    @ci = Simp::Cli::Config::Item::CliLocalPrivUser.new
  end

  describe '#validate' do
    it 'validates valid usernames' do
      expect( @ci.validate 'admin' ).to eq true
      expect( @ci.validate 'user_admin1' ).to eq true
      expect( @ci.validate 'user3-special' ).to eq true
      expect( @ci.validate '_admin$' ).to eq true
    end

    it "doesn't validate usernames" do
      expect( @ci.validate '1admin' ).to eq false
      expect( @ci.validate 'Admin' ).to eq false
      expect( @ci.validate 'this_is_longer_than_32_characters' ).to eq false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
