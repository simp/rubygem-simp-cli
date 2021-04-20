require 'simp/cli/config/items/data/cli_local_priv_user_has_ssh_authorized_keys'
require 'test_utils/etc_pwnam_struct'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliLocalPrivUserHasSshAuthorizedKeys do
  before :each do
    @username = 'local_user'
    @user_home = "/var/local/#{@username}"
    @keys_file = "#{@user_home}/.ssh/authorized_keys"
    @ci = Simp::Cli::Config::Item::CliLocalPrivUserHasSshAuthorizedKeys.new

    item = Simp::Cli::Config::Item::CliLocalPrivUser.new
    item.value = @username
    @ci.config_items[item.key] = item
  end

  context '#get_recommended_value' do
   let(:user_pwnam) {
      pwnam = TestUtils::EtcPwnamStruct.new
      pwnam.name   = @username
      pwnam.passwd = 'x'
      pwnam.uid    = 1778
      pwnam.gid    = 1778
      pwnam.gecos  = ''
      pwnam.shell  = '/bin/bash'
      pwnam
    }

    it "returns 'no' when local user does not exist" do
      expect(Etc).to receive(:getpwnam).with(@username).and_raise(ArgumentError)

      expect( @ci.get_recommended_value ).to eq('no')
    end

    it "returns 'no' when home directory is empty" do
      user_pwnam.dir = ''
      expect(Etc).to receive(:getpwnam).with(@username).and_return(user_pwnam)

      expect( @ci.get_recommended_value ).to eq('no')
    end

    it "returns 'no' when home directory is /dev/null" do
      user_pwnam.dir = '/dev/null'
      expect(Etc).to receive(:getpwnam).with(@username).and_return(user_pwnam)

      expect( @ci.get_recommended_value ).to eq('no')
    end

    it "returns 'no' when authorized_keys does not exist" do
      user_pwnam.dir = @user_home
      expect(Etc).to receive(:getpwnam).with(@username).and_return(user_pwnam)
      expect(File).to receive(:exist?).with(@keys_file).and_return(false)

      expect( @ci.get_recommended_value ).to eq('no')
    end

    it "returns 'yes' when authorized_keys does exist" do
      user_pwnam.dir = @user_home
      expect(Etc).to receive(:getpwnam).with(@username).and_return(user_pwnam)
      expect(File).to receive(:exist?).with(@keys_file).and_return(true)

      expect( @ci.get_recommended_value ).to eq('yes')
    end

    it 'fails when cli::local_priv_user Item does not exist' do
      @ci.config_items.delete('cli::local_priv_user')
      expect { @ci.get_recommended_value }.to raise_error(Simp::Cli::Config::InternalError,
        /Simp::Cli::Config::Item::CliLocalPrivUserHasSshAuthorizedKeys could not find cli::local_priv_user/)
    end
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end

