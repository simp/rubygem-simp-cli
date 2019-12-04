require 'simp/cli/kv/info_validator'
require 'spec_helper'

describe Simp::Cli::Kv::InfoValidator do
  describe '.validate_binary_key_info' do
    let (:key) { 'keyX' }

    it 'succeeds when key info is valid for binary value' do
      key_info = { 'value' => 'aGVsbG8gd29ybGQ=', 'encoding' => 'base64',
        'original_encoding' => 'ASCII-8BIT', 'metadata' => {} }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to_not raise_error
    end

    it "fails when 'encoding' set for non-string value" do
      key_info = { 'value' => true, 'encoding' => 'base64', 'metadata' => {} }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "'encoding' found for '#{key}'.\n"\
        ">> 'encoding' reserved for binary values")
    end

    it "fails when 'original_encoding' set for non-string value" do
      key_info = { 'value' => [ 'some', 'array'],
        'original_encoding' => 'ASCII-8BIT', 'metadata' => {} }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "'original_encoding' found for '#{key}'.\n"\
        ">> 'original_encoding' reserved for binary values")
    end

    it "fails when missing 'original_encoding'" do
      key_info = { 'value' => 'aGVsbG8gd29ybGQ=', 'encoding' => 'base64',
        'metadata' => {} }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "Missing 'original_encoding' for '#{key}' with binary value")
    end

    it "fails when missing 'encoding'" do
      key_info = { 'value' => 'aGVsbG8gd29ybGQ=',
        'original_encoding' => 'ASCII-8BIT', 'metadata' => {} }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "Missing 'encoding' for '#{key}' with binary value")
    end

    it "fails when 'value' is not strict Base64" do
      key_info = { 'value' => "aGVsbG8gd29ybGQ=\n", 'encoding' => 'base64',
        'original_encoding' => 'ASCII-8BIT', 'metadata' => {} }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "'value' for '#{key}' does not contain strict Base64 encoding")
    end
  end

  describe '.validate_key_info' do
    let (:key) { 'keyX' }

    it 'succeeds when key info is valid' do
      key_info = { 'value' => 'the value', 'metadata' => { 'history' => [] } }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to_not raise_error
    end

    it 'fails when key info is not a Hash' do
      key_info = [ 1, 2 ]
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        /Info for 'keyX' is not a Hash/)
    end

    it "fails when info is missing 'value' attribute for a key" do
      key_info = { 'metadata' => {} }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "Missing 'value' attribute for '#{key}'")
    end

    it "fails when info is missing 'metadata' attribute for a key" do
      key_info = { 'value' => 162 }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "Missing 'metadata' attribute for '#{key}'")
    end

    it "fails when info 'metadata' attribute for a key is not a Hash" do
      key_info = { 'value' => 'bob', 'metadata' => [] }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "'metadata' for '#{key}' is not a Hash")
    end

    it 'fails when info has invalid attributes for binary value' do
      key_info = { 'value' => 'aGVsbG8gd29ybGQ=', 'encoding' => 'base64',
        'metadata' => {} }
      expect{ Simp::Cli::Kv::InfoValidator.validate_key_info(key, key_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "Missing 'original_encoding' for '#{key}' with binary value")
    end
  end

  describe '.validate_list_info' do
    let (:folder) { 'folderA' }

    it 'succeeds when list info is valid' do
      list_info = {
       'keys'    => {
         'keyX' => { 'value' => 'value for keyX', 'metadata' => { 'history' => [] } },
         'keyY' => { 'value' => 'value for keyY', 'metadata' => {} }
       },
       'folders' => [ 'folder1', 'folder2']
      }

      expect{ Simp::Cli::Kv::InfoValidator.validate_list_info(folder, list_info) }
        .to_not raise_error
    end

    it 'fails when list info is not a Hash' do
      list_info = [ 1, 2 ]
      expect{ Simp::Cli::Kv::InfoValidator.validate_list_info(folder, list_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        /Info for '#{folder}' is not a Hash/)
    end

    it "fails when list info is missing 'keys' attribute" do
      list_info = { 'folders' => [] }
      expect{ Simp::Cli::Kv::InfoValidator.validate_list_info(folder, list_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "Missing 'keys' attribute for '#{folder}'")
    end

    it "fails when list info is missing 'folders' attribute" do
      list_info = {
        'keys'    => {
          'keyX' => { 'value' => 'value for keyX', 'metadata' => { 'history' => [] } },
        }
      }

      expect{ Simp::Cli::Kv::InfoValidator.validate_list_info(folder, list_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "Missing 'folders' attribute for '#{folder}'")
    end

    it "fails when list info 'folders' attribute for a list is not a Hash" do
      list_info = {
        'keys'    => {
          'keyX' => { 'value' => 'value for keyX', 'metadata' => { 'history' => [] } },
        },
        'folders' => { 'folder1' => 10 }
      }

      expect{ Simp::Cli::Kv::InfoValidator.validate_list_info(folder, list_info) }
        .to raise_error(Simp::Cli::ProcessingError,
        "'folders' for '#{folder}' is not an Array")
    end

    it 'fails when a malformed key info is in list info and validate_keys=true' do
      bad_info = {
       'keys'    => {
         'keyX' => { 'value' => 'value for keyX', 'metadata' => { 'history' => [] } },
         'keyY' => { 'value' => 'value for keyY'}
       },
       'folders' => [ 'folder1', 'folder2']
      }

      expect{ Simp::Cli::Kv::InfoValidator.validate_list_info(folder, bad_info, true) }
        .to raise_error(Simp::Cli::ProcessingError,
        "Missing 'metadata' attribute for 'keyY' in '#{folder}' list results")
    end

    it 'ignores malformed key info in list info by default' do
      bad_info = {
       'keys'    => {
         'keyX' => { 'value' => 'value for keyX', 'metadata' => { 'history' => [] } },
         'keyY' => { 'value' => 'value for keyY'}
       },
       'folders' => [ 'folder1', 'folder2']
      }

      expect{ Simp::Cli::Kv::InfoValidator.validate_list_info(folder, bad_info) }
        .to_not raise_error
    end
  end
end
