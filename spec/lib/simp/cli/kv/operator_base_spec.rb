require 'simp/cli/kv/operator_base'

require 'etc'
require 'spec_helper'

# ***WARNING***: Many tests in this file heavily make use of mocked behavior
# because the fundamental underlying operations, exec'ing `puppet apply`
# calls and reading files in transient directories, are not easily unit
# tested.  Full testing will be done in a detailed acceptance test!

describe Simp::Cli::Kv::OperatorBase do
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

    @base = Simp::Cli::Kv::OperatorBase.new(@env, @backend)
  end

  describe '#apply_options' do
    it 'should return options without :fail_filter when failure_message unset' do
      title = 'some operation'
      expected = {
        :title         => title,
        :env           => @env,
        :fail          => true,
        :group         => @group,
        :puppet_config => { 'vardir' => @vardir }
      }

      expect( @base.apply_options(title) ).to eq(expected)
    end

    it 'should return options with :fail_filter when failure_message set' do
      title = 'some operation'
      fail_msg = 'some failure message'
      expected = {
        :title         => title,
        :env           => @env,
        :fail          => true,
        :group         => @group,
        :puppet_config => { 'vardir' => @vardir },
        :fail_filter   => fail_msg
      }

      expect( @base.apply_options(title, fail_msg) ).to eq(expected)
    end
  end

  describe '#full_store_path' do
    it 'should return path within environment when not global' do
      expect( @base.full_store_path('keyA', false) ).to eq("/#{@env}/keyA")
    end

    it 'should return global path when global' do
      expect( @base.full_store_path('keyA', true) ).to eq('/keyA')
    end

    it 'should return remove extraneous slashes' do
      expect( @base.full_store_path('/folderX/', true) ).to eq('/folderX')
    end
  end

  describe '#simpkv_options' do
    it 'returns hash with environment set when not global' do
      expected = { 'backend' => @backend, 'environment' => @env }
      expect( @base.simpkv_options(false) ).to eq(expected)
    end

    it 'returns hash with environment empty when global' do
      expected = { 'backend' => @backend, 'environment' => '' }
      expect( @base.simpkv_options(true) ).to eq(expected)
    end
  end

  describe '#normalize_key_info' do
    it 'returns input info when value is a not a string' do
      key_info = { 'value' => [ 'some', 'array'], 'metadata' => { 'id' => 1 } }
      expect( @base.normalize_key_info(key_info) ).to eq(key_info)
    end

    it 'returns input info when value is a non-binary string' do
      key_info = { 'value' => 'some string', 'metadata' => { 'id' => 1 } }
      expect( @base.normalize_key_info(key_info) ).to eq(key_info)
    end

    it "returns encoded binary value with 'encoding' and 'original_encoding'" do
      binary_string = 'some string'.force_encoding('ASCII-8BIT')
      key_info = { 'value' => binary_string, 'metadata' => { 'id' => 1 } }
      expected = { 'value' => Base64.strict_encode64(binary_string),
        'encoding' => 'base64', 'original_encoding' => 'ASCII-8BIT',
        'metadata' => { 'id' => 1 } }
      expect( @base.normalize_key_info(key_info) ).to eq(expected)
    end
  end

  describe '#normalize_list' do
    it 'should encode values for all keys with binary values' do
      binary_string1 = 'some string'.force_encoding('ASCII-8BIT')
      binary_string2 = 'some other string'.force_encoding('ASCII-8BIT')
      list_info = {
        'keys' => {
          'keyA' => { 'value' => binary_string1, 'metadata' => {}},
          'keyB' => { 'value' => 'foo', 'metadata' => { 'bar' => 'baz' } },
          'keyC' => { 'value' => binary_string2, 'metadata' => { 'bar' => 'baz' } }
         },
        'folders' => [ 'folder1', 'folder2' ]
      }

      expected = {
        'keys' => {
          'keyA' => {
            'value' => Base64.strict_encode64(binary_string1),
            'encoding' => 'base64',
            'original_encoding' => 'ASCII-8BIT',
            'metadata' => {}
          },
          'keyB' => { 'value' => 'foo', 'metadata' => { 'bar' => 'baz' } },
          'keyC' => {
            'value' => Base64.strict_encode64(binary_string2),
            'encoding' => 'base64',
            'original_encoding' => 'ASCII-8BIT',
            'metadata' => { 'bar' => 'baz' }
           }
         },
        'folders' => [ 'folder1', 'folder2' ]
      }

      expect( @base.normalize_list(list_info) ).to eq(expected)
    end
  end
end
