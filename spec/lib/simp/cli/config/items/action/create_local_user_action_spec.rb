require 'simp/cli/config/items/action/create_local_user_action'
require 'fileutils'

require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CreateLocalUserAction do
  before :each do
    @ci = Simp::Cli::Config::Item::CreateLocalUserAction.new
    @ci.silent = true

    @user = 'local_admin'
    user_item = Simp::Cli::Config::Item::CliLocalPrivUser.new
    user_item.value = @user
    @ci.config_items[user_item.key] = user_item

    @pwd_hash = '$6$salt$passwordhash'
    pwd_item = Simp::Cli::Config::Item::CliLocalPrivUserPassword.new
    pwd_item.value = @pwd_hash
    pwd_item.config_items[user_item.key] = user_item
    @ci.config_items[pwd_item.key] = pwd_item
  end

  describe "#apply" do
    let(:group_cmd) { "puppet resource group #{@user} ensure=present  --to_yaml" }
    let(:user_cmd) {
      [
      "puppet resource user #{@user} ensure=present",
      "groups='#{@user}'",
      "password='#{@pwd_hash}'",
      "home=/var/local/#{@user}",
      'manageHome=true',
      'shell=/bin/bash',
      '--to_yaml'
      ].join(' ')
    }

    let(:group_result) { {
      :status => true,
      :stderr => '',
      :stdout => <<~EOM
        Notice: /Group[#{@user}]/ensure: created
        ---
        group:
          #{@user}:
            ensure: present
            provider: gpasswd
        EOM
    } }

    let(:user_result) { {
      :status => true,
      :stderr => '',
      :stdout => <<~EOM
        Notice: /User[#{@user}]/ensure: created
        ---
        user:
          #{@user}:
            ensure: present
            groups:
            - #{@user}
            home: "/var/local/#{@user}"
            password: "#{@pwd_hash}"
            provider: useradd
            shell: "/bin/bash"
        EOM
    } }
    let(:bad_result) { {
      # puppet resource can have an exit code of 0, even when it has failed
      :status => true,
      :stderr => 'some error message',
      :stdout => 'ensure: absent'
     } }

    it 'returns :succeeded when both user and group were created' do
       # allow(@ci).to receive(:execute).with(any_args).and_call_original
      expect(@ci).to receive(:run_command).with(group_cmd).and_return(group_result)
      expect(@ci).to receive(:run_command).with(user_cmd).and_return(user_result)
      @ci.apply

      expect(@ci.applied_status).to eq :succeeded
    end

    it 'returns :failed when the group cannot be created' do
      expect(@ci).to receive(:run_command).with(group_cmd).and_return(bad_result)
      @ci.apply

      expect(@ci.applied_status).to eq :failed
    end

    it 'returns :failed when the user cannot be created' do
      expect(@ci).to receive(:run_command).with(group_cmd).and_return(group_result)
      expect(@ci).to receive(:run_command).with(user_cmd).and_return(bad_result)
      @ci.apply

      expect(@ci.applied_status).to eq :failed
    end

    it 'fails when cli::local_priv_user Item does not exist' do
      @ci.config_items.delete('cli::local_priv_user')
      expect { @ci.apply }.to raise_error(Simp::Cli::Config::InternalError,
          /Simp::Cli::Config::Item::CreateLocalUserAction could not find cli::local_priv_user/)
    end

  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'Creation of local user unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end
