require 'simp/cli/config/items/data/pam_access_users'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::PamAccessUsers do
  before :each do
    @ci = Simp::Cli::Config::Item::PamAccessUsers.new

  end

  describe '#get_recommended_value' do
    it 'returns value based on cli::local_priv_user when cli::local_priv_user exists' do
      item = Simp::Cli::Config::Item::CliLocalPrivUser.new
      item.value = 'local_admin'
      @ci.config_items[item.key] = item

      expected = { 'local_admin'  => { 'origins' => [ 'ALL' ] } }
      expect(@ci.get_recommended_value).to eq(expected)
    end

    it 'fails when cli::local_priv_user does not exist' do
      expect { @ci.get_recommended_value }.to raise_error(Simp::Cli::Config::InternalError,
        /Simp::Cli::Config::Item::PamAccessUsers could not find cli::local_priv_user/)
    end
  end

  describe '#validate' do
    it 'always returns true' do
      expect( @ci.validate('do/not/care') ).to be true
    end
  end

  describe '#query' do
    it 'always returns nil' do
      expect( @ci.query ).to be_nil
    end
  end

  describe '#print_summary' do
    it 'always returns nil' do
      expect( @ci.print_summary ).to be_nil
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
