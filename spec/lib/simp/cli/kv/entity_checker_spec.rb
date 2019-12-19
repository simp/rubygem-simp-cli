require 'simp/cli/kv/entity_checker'

require 'etc'
require 'spec_helper'

# ***WARNING***: Many tests in this file heavily make use of mocked behavior
# because the fundamental underlying operations, exec'ing `puppet apply`
# calls and reading files in transient directories, are not easily unit
# tested.  Full testing will be done in a detailed acceptance test!

describe Simp::Cli::Kv::EntityChecker do
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

    @checker = Simp::Cli::Kv::EntityChecker.new(@env, @backend)
  end

  describe '#exists' do
    it 'returns true when key/folder exists in the environment' do
      allow(@checker).to receive(:get_exists).with(key, false)
        .and_return(true)

      expect( @checker.exists(key, false) ).to eq true
    end

    it 'returns true when global key/folder exists' do
      allow(@checker).to receive(:get_exists).with(key, true)
        .and_return(true)

      expect( @checker.exists(key, true) ).to eq true
    end

    it 'returns false when key/folder does not exist in the environment' do
      allow(@checker).to receive(:get_exists).with(key, false)
        .and_return(false)

      expect( @checker.exists(key, false) ).to eq false
    end

    it 'returns false when global key/folder does not exist' do
      allow(@checker).to receive(:get_exists).with(key, true)
        .and_return(false)

      expect( @checker.exists(key, true) ).to eq false
    end

    it 'fails when #get_exists fails' do
      err_msg = 'Connection failure'
      allow(@checker).to receive(:get_exists).with(key, false)
        .and_raise(Simp::Cli::ProcessingError, err_msg)

      expect { @checker.exists(key, false) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Folder/key exists failed: #{err_msg}")
    end
  end

  describe '#get_exists' do
    it 'should return true when manifest apply succeeds and log includes '\
       'exists string' do

      err_msg = "Error: Evaluation Error: Error while evaluating a Function "\
        "Call, '#{folder}' EXISTS (location info)"

      results = { :stderr => err_msg }
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return(results)

      expect( @checker.get_exists(folder, false) ).to be true
    end

    it 'should return false when manifest apply succeeds and log does not '\
       'include exists string' do

      err_msg = "Error: Evaluation Error: Error while evaluating a Function "\
        "Call, '#{folder}' DOES NOT EXIST (location info)"

      results = { :stderr => err_msg }
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return(results)

      expect( @checker.get_exists(folder, false) ).to be false
    end

    it 'should fail when #apply_manifest_with_spawn fails' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_raise(Simp::Cli::ProcessingError, 'Connection failure')

      expect{ @checker.get_exists(folder, true) }.to raise_error(
        Simp::Cli::ProcessingError, 'Connection failure')
    end
  end
end
