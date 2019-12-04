require 'simp/cli/kv/key_deleter'

require 'etc'
require 'spec_helper'

# ***WARNING***: Many tests in this file heavily make use of mocked behavior
# because the fundamental underlying operations, exec'ing `puppet apply`
# calls and reading files in transient directories, are not easily unit
# tested.  Full testing will be done in a detailed acceptance test!

describe Simp::Cli::Kv::KeyDeleter do
  let(:key) { 'keyX' }
  let(:value) { 'value for keyX' }
  let(:metadata) { { 'history' => [] } }
  let(:folder) { 'folderA' }

  before :each do
    @user  = Etc.getpwuid(Process.uid).name
    @group = Etc.getgrgid(Process.gid).name
    @env = 'production'
    @backend = 'default'
    @vardir = '/server/var/dir'
    puppet_info = {
      :config => {
        'user'   => @user,
        'group'  => @group,
        'vardir' => @vardir
      }
    }

    allow(Simp::Cli::Utils).to receive(:puppet_info).with(@env)
      .and_return(puppet_info)

    @deleter = Simp::Cli::Kv::KeyDeleter.new(@env, @backend)
  end

  describe '#delete' do
    it 'removes key in the environment' do
      allow(@deleter).to receive(:delete_key).with(key, false)
        .and_return({}) # don't care about return

      expect{ @deleter.delete(key, false) }.to_not raise_error
    end

    it 'removes global key' do
      allow(@deleter).to receive(:delete_key).with(key, true)
        .and_return({}) # don't care about return

      expect{ @deleter.delete(key, true) }.to_not raise_error
    end

    it 'fails when #delete_key fails' do
      err_msg = "Key '#{key}' not found"
      allow(@deleter).to receive(:delete_key).with(key, false)
        .and_raise(Simp::Cli::ProcessingError, err_msg)

      expect { @deleter.delete(key, false) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Key delete failed: #{err_msg}")
    end
  end

  describe '#delete_key' do
    it 'should succeed when #apply_manifest_with_spawn succeeds' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return({}) # don't care about return

      expect{ @deleter.delete_key(key, true) }.to_not raise_error
    end

    it 'should fail when #apply_manifest_with_spawn fails' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_raise(Simp::Cli::ProcessingError, 'Connection failure')

      expect{ @deleter.delete_key(key, true) }.to raise_error(
        Simp::Cli::ProcessingError, 'Connection failure')
    end
  end
end
