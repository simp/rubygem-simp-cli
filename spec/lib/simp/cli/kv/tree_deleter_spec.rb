require 'simp/cli/kv/tree_deleter'

require 'etc'
require 'spec_helper'

# ***WARNING***: Many tests in this file heavily make use of mocked behavior
# because the fundamental underlying operations, exec'ing `puppet apply`
# calls and reading files in transient directories, are not easily unit
# tested.  Full testing will be done in a detailed acceptance test!

describe Simp::Cli::Kv::TreeDeleter do
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

    @deleter = Simp::Cli::Kv::TreeDeleter.new(@env, @backend)
  end

  describe '#deletetree' do
    it 'removes folder in the environment' do
      allow(@deleter).to receive(:delete_folder).with(folder, false)
        .and_return({}) # don't care about return

      expect{ @deleter.deletetree(folder, false) }.to_not raise_error
    end

    it 'removes global key' do
      allow(@deleter).to receive(:delete_folder).with(folder, true)
        .and_return({}) # don't care about return

      expect{ @deleter.deletetree(folder, true) }.to_not raise_error
    end

    it 'fails when #delete_folder fails' do
      err_msg = "Folder '#{folder}' not found"
      allow(@deleter).to receive(:delete_folder).with(folder, false)
        .and_raise(Simp::Cli::ProcessingError, err_msg)

      expect { @deleter.deletetree(folder, false) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Folder delete failed: #{err_msg}")
    end
  end

  describe '#delete_folder' do
    it 'should succeed when #apply_manifest_with_spawn succeeds' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return({}) # don't care about return

      expect{ @deleter.delete_folder(key, true) }.to_not raise_error
    end

    it 'should fail when #apply_manifest_with_spawn fails' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_raise(Simp::Cli::ProcessingError, 'Connection failure')

      expect{ @deleter.delete_folder(folder, true) }.to raise_error(
        Simp::Cli::ProcessingError, 'Connection failure')
    end
  end
end
