require 'simp/cli/config/items/action/warn_verify_user_access_after_bootstrap_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::WarnVerifyUserAccessAfterBootstrapAction do
  before :each do
    @ci  = Simp::Cli::Config::Item::WarnVerifyUserAccessAfterBootstrapAction.new

    item = Simp::Cli::Config::Item::CliLocalPrivUser.new
    item.value = 'local_admin'
    @ci.config_items[item.key] = item

    item = Simp::Cli::Config::Item::CliNetworkHostname.new
    item.value = 'simp.test.local'
    @ci.config_items[item.key] = item
  end

  describe '#apply' do
    it 'sets applied_status to deferred' do
      @ci.apply
      expect( @ci.applied_status ).to eq :deferred
      expected = <<~EOM
        'local_admin' access verification after `simp bootstrap` deferred:
            'local_admin' access configuration requires manual verification
      EOM
      expect( @ci.apply_summary ).to eq(expected.strip)
    end

    it 'fails when cli::local_priv_user Item does not exist' do
      @ci.config_items.delete('cli::local_priv_user')
      expect { @ci.apply }.to raise_error(Simp::Cli::Config::InternalError,
        /Simp::Cli::Config::Item::WarnVerifyUserAccessAfterBootstrapAction could not find cli::local_priv_user/)
    end

    it 'fails when cli::network:hostname Item does not exist' do
      @ci.config_items.delete('cli::network::hostname')
      expect { @ci.apply }.to raise_error(Simp::Cli::Config::InternalError,
        /Simp::Cli::Config::Item::WarnVerifyUserAccessAfterBootstrapAction could not find cli::network::hostname/)
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq(
        "'local_admin' access verification after `simp bootstrap` unattempted")
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
