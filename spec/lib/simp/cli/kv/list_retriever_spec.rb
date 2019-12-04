require 'simp/cli/kv/list_retriever'

require 'etc'
require 'spec_helper'

# ***WARNING***: Many tests in this file heavily make use of mocked behavior
# because the fundamental underlying operations, exec'ing `puppet apply`
# calls and reading files in transient directories, are not easily unit
# tested.  Full testing will be done in a detailed acceptance test!

describe Simp::Cli::Kv::ListRetriever do
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

    @retriever = Simp::Cli::Kv::ListRetriever.new(@env, @backend)
  end

  describe '#list' do
    let(:list_info) { {
      'keys' => {
        'keyA' => { 'value' => true, 'metadata' => {}},
        'keyB' => { 'value' => 'foo', 'metadata' => { 'bar' => 'baz' } }
       },
      'folders' => [ 'folder1', 'folder2' ]
    } }

    it 'returns hash with folder list for folder in the environment' do
      allow(@retriever).to receive(:get_folder_list).with(folder, false)
        .and_return(list_info)

      expect( @retriever.list(folder, false) ).to eq(list_info)
    end

    it 'returns hash with folder list for global folder' do
      allow(@retriever).to receive(:get_folder_list).with(folder, true)
        .and_return(list_info)

      expect( @retriever.list(folder, true) ).to eq(list_info)
    end

    it 'fails when retrieved info is malformed' do
      bad_info = { 'folders' => [ 'folder1', 'folder2' ] }
      allow(@retriever).to receive(:get_folder_list).with(folder, false)
        .and_return(bad_info)

      expect { @retriever.list(folder, false) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Folder list failed: List info malformed: Missing 'keys' attribute for '#{folder}'")
    end

    it 'fails when #get_folder_list fails' do
      allow(@retriever).to receive(:get_folder_list).with(folder, false)
        .and_raise( Simp::Cli::ProcessingError, 'Connection failure')

      expect { @retriever.list(folder, false) }.to raise_error(
        Simp::Cli::ProcessingError,
        'Folder list failed: Connection failure')
    end
  end

  describe '#get_folder_list' do
    let(:list_info) { {
      'keys' => {
        'keyA' => { 'value' => true, 'metadata' => {}},
        'keyB' => { 'value' => 'foo', 'metadata' => { 'bar' => 'baz' } }
       },
      'folders' => [ 'folder1', 'folder2' ]
    } }

    it 'applies manifest to retrieve folder list and then returns it' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return({}) # don't care about return

      allow(Simp::Cli::ApplyUtils).to receive(:load_yaml)
        .and_return(list_info)

      expect( @retriever.get_folder_list(folder, true) ).to eq(list_info)
    end

    it 'fails when manifest apply fails' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_raise(Simp::Cli::ProcessingError, 'Connection failed')

      expect{ @retriever.get_folder_list(folder, true) }.to raise_error(
        Simp::Cli::ProcessingError, 'Connection failed')
    end

    it 'fails when interim password list YAML fails to load' do
      allow(Simp::Cli::ApplyUtils).to receive(:apply_manifest_with_spawn)
        .and_return({}) # don't care about return

      allow(Simp::Cli::ApplyUtils).to receive(:load_yaml).and_raise(
        Simp::Cli::ProcessingError, 'Failed to load folder list YAML')

      expect{ @retriever.get_folder_list(folder, false) }.to raise_error(
        Simp::Cli::ProcessingError, 'Failed to load folder list YAML')
    end
  end
end
