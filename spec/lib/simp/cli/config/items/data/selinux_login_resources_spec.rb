require 'simp/cli/config/items/data/selinux_login_resources'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SelinuxLoginResources do
  before :each do
    @ci = Simp::Cli::Config::Item::SelinuxLoginResources.new

  end

  describe '#get_recommended_value' do
    it 'returns value based on cli::local_priv_user when cli::local_priv_user Item exists' do
      item = Simp::Cli::Config::Item::CliLocalPrivUser.new
      item.value = 'local_admin'
      @ci.config_items[item.key] = item

      expected = {
        'local_admin'  => {
          'seuser'    => 'staff_u',
          'mls_range' => 's0-s0:c0.c1023'
        }
      }
      expect(@ci.get_recommended_value).to eq(expected)
    end

    it 'fails when cli::local_priv_user Item does not exist' do
      expect { @ci.get_recommended_value }.to raise_error(Simp::Cli::Config::InternalError,
        /Simp::Cli::Config::Item::SelinuxLoginResources could not find cli::local_priv_user/)
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
