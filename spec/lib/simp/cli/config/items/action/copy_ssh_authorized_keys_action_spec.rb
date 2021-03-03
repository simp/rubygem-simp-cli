require 'simp/cli/config/items/action/copy_ssh_authorized_keys_action'
require 'test_utils/etc_pwnam_struct'
require_relative '../spec_helper'
require 'fileutils'

describe Simp::Cli::Config::Item::CopySshAuthorizedKeysAction do
  before :each do
    @tmp_dir       = Dir.mktmpdir( File.basename(__FILE__) )
    @local_keys_dir = File.join(@tmp_dir, 'local_keys')
    @ci            = Simp::Cli::Config::Item::CopySshAuthorizedKeysAction.new
    @ci.dest_dir   = @local_keys_dir
    @ci.silent     = true   # turn off command line summary on stdout

    @username = 'local_admin'
    item = Simp::Cli::Config::Item::CliLocalPrivUser.new
    item.value = @username
    @ci.config_items[item.key] = item

    @user_home = File.join(@tmp_dir, 'home', @username)
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
   end

  context '#apply' do
   let(:user_pwnam) {
      pwnam = TestUtils::EtcPwnamStruct.new
      pwnam.name   = @username
      pwnam.passwd = 'x'
      pwnam.uid    = 1778
      pwnam.gid    = 1778
      pwnam.gecos  = ''
      pwnam.dir    = @user_home
      pwnam.shell  = '/bin/bash'
      pwnam
    }


    it 'sets applied_status to :failed when local user not found in /etc/passwd' do
      expect(Etc).to receive(:getpwnam).with(@username).and_raise(ArgumentError)
      @ci.apply
      expect( @ci.applied_status ).to eq(:failed)
    end

    it 'sets applied_status to :unnecessary when local user has no authorized_keys file' do
      FileUtils.mkdir_p(@user_home)
      expect(Etc).to receive(:getpwnam).and_return(user_pwnam)

      @ci.apply
      expect( @ci.applied_status ).to eq(:unnecessary)
    end

    it 'copies authorized_keys and sets applied_status to :succeeded' do
      user_ssh_dir = File.join(@user_home, '.ssh')
      FileUtils.mkdir_p(user_ssh_dir)
      keys_file = File.join(user_ssh_dir, 'authorized_keys')
      File.open(keys_file, 'w') { |file| file.puts 'key info' }
      expect(Etc).to receive(:getpwnam).and_return(user_pwnam)

      @ci.apply
      expect( @ci.applied_status ).to eq(:succeeded)
      dest = File.join(@local_keys_dir, @username)
      expect( File.exist?(dest) ).to be true
      expect( File.read(dest) ).to eq(File.read(keys_file))
    end

    it 'sets applied_status to :failed when copy fails' do
      user_ssh_dir = File.join(@user_home, '.ssh')
      FileUtils.mkdir_p(user_ssh_dir)
      keys_file = File.join(user_ssh_dir, 'authorized_keys')
      File.open(keys_file, 'w') { |file| file.puts 'key info' }
      expect(Etc).to receive(:getpwnam).and_return(user_pwnam)
      dest = File.join(@local_keys_dir, @username)
      expect(FileUtils).to receive(:cp).with(keys_file, dest).and_raise(Errno::ENOENT)

      @ci.apply
      expect( @ci.applied_status ).to eq(:failed)
    end

    it 'fails when cli::local_priv_user Item does not exist' do
      @ci.config_items.delete('cli::local_priv_user')
      expect { @ci.apply }.to raise_error(Simp::Cli::Config::InternalError,
        /Simp::Cli::Config::Item::CopySshAuthorizedKeysAction could not find cli::local_priv_user/)
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expected = "Copy of user ssh authorized keys to #{@local_keys_dir}/ unattempted"
      expect(@ci.apply_summary).to eq(expected)
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end

