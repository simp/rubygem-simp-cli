require 'simp/cli/kv/key_storer'

require 'etc'
require 'spec_helper'

# ***WARNING***: Many tests in this file heavily make use of mocked behavior
# because the fundamental underlying operations, exec'ing `puppet apply`
# calls and reading files in transient directories, are not easily unit
# tested.  Full testing will be done in a detailed acceptance test!

describe Simp::Cli::Kv::KeyStorer do
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

    @storer = Simp::Cli::Kv::KeyStorer.new(@env, @backend)
  end

  describe '#put' do
    it 'sets non-binary key in the environment' do
      put_key_args = [ key, value, metadata, false ]
      allow(@storer).to receive(:put_key).with(*put_key_args)
        .and_return({}) # don't care about return

      args = [ key, value, metadata, false, false ]
      expect{ @storer.put(*args) }.to_not raise_error
    end

    it 'sets binary key in the environment' do
      put_bin_key_args = [ key, value, metadata, false ]
      allow(@storer).to receive(:put_binary_key).with(*put_bin_key_args)
        .and_return({}) # don't care about return

      args = [ key, value, metadata, true, false ]
      expect{ @storer.put(*args) }.to_not raise_error
    end

    it 'sets global key' do
      put_key_args = [ key, value, metadata, true ]
      allow(@storer).to receive(:put_key).with(*put_key_args)
        .and_return({}) # don't care about return

      args = [ key, value, metadata, false, true ]
      expect{ @storer.put(*args) }.to_not raise_error
    end

    it 'fails when metadata is not a hash' do
      args = [ key, value, [], false, true ]
      expect { @storer.put(*args) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Key set failed: Metadata for '#{key}' is not a Hash")
    end

    it 'fails when #put_key fails' do
      put_key_args = [ key, value, metadata, false ]
      err_msg = 'Connection failure'
      allow(@storer).to receive(:put_key).with(*put_key_args)
        .and_raise(Simp::Cli::ProcessingError, err_msg)

      args = [ key, value, metadata, false, false ]
      expect { @storer.put(*args) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Key set failed: #{err_msg}")
    end

    it 'fails when #put_binary_key fails' do
      put_bin_key_args = [ key, value, metadata, false ]
      err_msg = 'Connection failure'
      allow(@storer).to receive(:put_binary_key).with(*put_bin_key_args)
        .and_raise(Simp::Cli::ProcessingError, err_msg)

      args = [ key, value, metadata, true, false ]
      expect { @storer.put(*args) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Key set failed: #{err_msg}")
    end
  end

  describe '#put_key' do
    it 'should succeed when #apply_manifest_with_spawn succeeds' do
      args = [ key, value, metadata, false ]
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return({}) # don't care about return

      expect{ @storer.put_key(*args) }.to_not raise_error
    end

    it 'should fail when #apply_manifest_with_spawn fails' do
      args = [ key, value, metadata, false ]
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_raise(Simp::Cli::ProcessingError, 'Connection failure')

      expect{ @storer.put_key(*args) }.to raise_error(
        Simp::Cli::ProcessingError, 'Connection failure')
    end
  end

  describe '#put_binary_key' do
    it 'should succeed when #apply_manifest_with_spawn succeeds' do
      args = [ key, value, metadata, false ]
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return({}) # don't care about return

      expect{ @storer.put_binary_key(*args) }.to_not raise_error
    end

    it 'should fail when #apply_manifest_with_spawn fails' do
      args = [ key, value, metadata, false ]
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_raise(Simp::Cli::ProcessingError, 'Connection failure')

      expect{ @storer.put_binary_key(*args) }.to raise_error(
        Simp::Cli::ProcessingError, 'Connection failure')
    end
  end

  describe '#put_key' do
    it 'should succeed when #apply_manifest_with_spawn succeeds' do
      args = [ key, value, metadata, false ]
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return({}) # don't care about return

      expect{ @storer.put_key(*args) }.to_not raise_error
    end

    it 'should fail when #apply_manifest_with_spawn fails' do
      args = [ key, value, metadata, false ]
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_raise(Simp::Cli::ProcessingError, 'Connection failure')

      expect{ @storer.put_key(*args) }.to raise_error(
        Simp::Cli::ProcessingError, 'Connection failure')
    end
  end
end
