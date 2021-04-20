require 'simp/cli/config/items/data/sudo_user_specifications'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SudoUserSpecifications do
  before :each do
    @ci = Simp::Cli::Config::Item::SudoUserSpecifications.new
    item = Simp::Cli::Config::Item::CliLocalPrivUser.new
    item.value = 'local_admin'
    @ci.config_items[item.key] = item
  end

  describe '#get_recommended_value' do
    context 'when local privileged user does not exist' do
      it 'returns hash for cli::local_priv_user with passwd = true' do
        item = Simp::Cli::Config::Item::CliLocalPrivUserExists.new
        item.value = false
        @ci.config_items[item.key] = item

        expected = {
          'local_admin_su'  => {
            'user_list' => [ 'local_admin' ],
            'cmnd'      => [ 'ALL' ],
            'passwd'    => true,
            'options'   =>  { 'role'=> 'unconfined_r' }
          }
        }
        expect(@ci.get_recommended_value).to eq(expected)
      end
    end

    context 'when local privileged user exists and has ssh authorized keys' do
      it 'returns hash for cli::local_priv_user with passwd = false' do
        item = Simp::Cli::Config::Item::CliLocalPrivUserExists.new
        item.value = true
        @ci.config_items[item.key] = item

        item = Simp::Cli::Config::Item::CliLocalPrivUserHasSshAuthorizedKeys.new
        item.value = true
        @ci.config_items[item.key] = item

        expected = {
          'local_admin_su'  => {
            'user_list' => [ 'local_admin' ],
            'cmnd'      => [ 'ALL' ],
            'passwd'    => false,
            'options'   =>  { 'role'=> 'unconfined_r' }
          }
        }
        expect(@ci.get_recommended_value).to eq(expected)
      end
    end

    context 'when local privileged user exists but does not have ssh authorized keys' do
      it 'returns hash for cli::local_priv_user with passwd = true' do
        item = Simp::Cli::Config::Item::CliLocalPrivUserExists.new
        item.value = true
        @ci.config_items[item.key] = item

        item = Simp::Cli::Config::Item::CliLocalPrivUserHasSshAuthorizedKeys.new
        item.value = false
        @ci.config_items[item.key] = item

        expected = {
          'local_admin_su'  => {
            'user_list' => [ 'local_admin' ],
            'cmnd'      => [ 'ALL' ],
            'passwd'    => true,
            'options'   =>  { 'role'=> 'unconfined_r' }
          }
        }
        expect(@ci.get_recommended_value).to eq(expected)
      end
    end

    context 'when required items are missing' do
      it 'fails when cli::local_priv_user does not exist' do
        @ci.config_items.delete('cli::local_priv_user')
        expect { @ci.get_recommended_value }.to raise_error(Simp::Cli::Config::InternalError,
        /Simp::Cli::Config::Item::SudoUserSpecifications could not find cli::local_priv_user/)
      end

      it 'fails when cli::local_priv_user_exists does not exist' do
        expect { @ci.get_recommended_value }.to raise_error(Simp::Cli::Config::InternalError,
        /Simp::Cli::Config::Item::SudoUserSpecifications could not find cli::local_priv_user_exists/)
      end

      it 'fails when cli::local_priv_user_exists=true and cli::local_priv_user_has_ssh_authorized_keys does not exist' do
        item = Simp::Cli::Config::Item::CliLocalPrivUserExists.new
        item.value = true
        @ci.config_items[item.key] = item
        expect { @ci.get_recommended_value }.to raise_error(Simp::Cli::Config::InternalError,
        /Simp::Cli::Config::Item::SudoUserSpecifications could not find cli::local_priv_user_has_ssh_authorized_keys/)
      end
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
