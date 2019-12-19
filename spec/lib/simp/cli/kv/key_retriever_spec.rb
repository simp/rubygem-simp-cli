require 'simp/cli/kv/key_retriever'

require 'etc'
require 'spec_helper'

# ***WARNING***: Many tests in this file heavily make use of mocked behavior
# because the fundamental underlying operations, exec'ing `puppet apply`
# calls and reading files in transient directories, are not easily unit
# tested.  Full testing will be done in a detailed acceptance test!

describe Simp::Cli::Kv::KeyRetriever do
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

    @retriever = Simp::Cli::Kv::KeyRetriever.new(@env, @backend)
  end

  describe '#get' do
    let(:key_info) { {
      'value'    => { 'password' => 'password1', 'salt' => 'salt1'},
      'metadata' => { 'history' => [] }
    } }

    it 'returns hash with key info for key in the environment' do
      allow(@retriever).to receive(:get_key_info).with(key, false)
        .and_return(key_info)

      expect( @retriever.get(key, false) ).to eq(key_info)
    end

    it 'returns hash with key info for global key' do
      allow(@retriever).to receive(:get_key_info).with(key, true)
        .and_return(key_info)

      expect( @retriever.get(key, true) ).to eq(key_info)
    end

    it "fails when retrieved info is malformed" do
      bad_info = { 'metadata' => { 'foo' => 'bar'} }
      allow(@retriever).to receive(:get_key_info).with(key, false)
        .and_return(bad_info)

      expect { @retriever.get(key, false) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Key get failed: Key info malformed: Missing 'value' attribute for '#{key}'")
    end

    it 'fails when #get_key_info fails' do
      allow(@retriever).to receive(:get_key_info).with(key, false)
        .and_raise( Simp::Cli::ProcessingError, 'Connection failure')

      expect { @retriever.get(key, false) }.to raise_error(
        Simp::Cli::ProcessingError,
        'Key get failed: Connection failure')
    end
  end

  describe '#get_key_info' do
    let(:key_info) { {
      'value'    => { 'password' => 'password1', 'salt' => 'salt' },
      'metadata' => { 'history'  => [] }
    } }

    it 'applies manifest to retrieve key info and then returns it' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return({}) # don't care about return

      allow(Simp::Cli::ApplyUtils).to receive(:load_yaml)
        .and_return(key_info)

      expect( @retriever.get_key_info(key, true) ).to eq(key_info)
    end

    it 'fails when manifest apply fails' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_raise(Simp::Cli::ProcessingError, 'Connection failure')

      expect{ @retriever.get_key_info(key, true) }
        .to raise_error(Simp::Cli::ProcessingError, 'Connection failure')
    end

    it 'fails when interim password info YAML fails to load' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return({}) # don't care about return

      allow(Simp::Cli::ApplyUtils).to receive(:load_yaml).and_raise(
        Simp::Cli::ProcessingError, 'Failed to load key info YAML')

      expect{ @retriever.get_key_info(key, true) }
        .to raise_error(Simp::Cli::ProcessingError,
        'Failed to load key info YAML')
    end
  end
end
