require 'simp/cli/puppetfile/local_simp_puppet_modules'
require 'spec_helper'

describe Simp::Cli::Puppetfile::LocalSimpPuppetModules do
  TEST_FILES = File.join(__dir__, 'files')

  # Mock data about 1-n modules
  USR_MOD_DIR  = '/usr/share/simp/modules'.freeze
  SIMP_GIT_DIR = '/usr/share/simp/git/puppet_modules'.freeze
  TEST_MODULES = Hash[
    %w[simplib stdlib].map do |k|
      [k, {
        :metadata_json_path => "#{USR_MOD_DIR}/#{k}/metadata.json",
        :metadata_json_str => File.read(File.join(TEST_FILES, "#{k}.metadata.json"))
      }]
    end
  ]
  MDJ_FILES_GLOB  = File.join(USR_MOD_DIR, '*', 'metadata.json')
  SINGLE_MDJ_FILE = File.join(USR_MOD_DIR, TEST_MODULES.keys.first, 'metadata.json')
  SINGLE_METADATA = JSON.parse(TEST_MODULES[TEST_MODULES.keys.first][:metadata_json_str])

  subject(:described_object) { described_class.new(USR_MOD_DIR, SIMP_GIT_DIR) }

  before(:each) do
    # Pass through partial mocks when we don't need them
    allow(File).to receive(:directory?).with(any_args).and_call_original
    allow(File).to receive(:exist?).with(any_args).and_call_original
    allow(File).to receive(:read).with(any_args).and_call_original
    allow(Dir).to receive(:[]).with(any_args).and_call_original
    allow(Dir).to receive(:[]).with(any_args).and_call_original

    allow(File).to receive(:directory?).with(USR_MOD_DIR).and_return(true)
    allow(Time).to receive(:now).and_return(
      # weird, but less brittle than `receive_message_chain`:
      object_double(Time.now, :utc => instance_double('x', :strftime => 'YYYY-mm-dd HH:MM:SSZ'))
    )

    # Mock a complete environment for each module
    allow(Dir).to receive(:[]).with(MDJ_FILES_GLOB).and_return(
      TEST_MODULES.map { |_k, v| v[:metadata_json_path] }
    )
    TEST_MODULES.each do |k, v|
      metadata = JSON.parse(v[:metadata_json_str])
      mdj_file = v[:metadata_json_path]
      mod_to_s = <<-TO_S.gsub(%r{ {8}}, '')
        mod '#{metadata['name']}',
          :git => 'file://#{SIMP_GIT_DIR}/#{metadata['name']}.git',
          :version => '#{metadata['version']}'
      TO_S
      allow(File).to receive(:exist?).with(mdj_file).and_return(true)
      allow(File).to receive(:read).with(mdj_file).and_return(v[:metadata_json_str])
      allow(Simp::Cli::Puppetfile::LocalSimpPuppetModule).to \
        receive(:new).with(metadata, SIMP_GIT_DIR).and_return(
          object_double("Mock LocalSimpPuppetModule (#{k})", :to_s => mod_to_s)
        )
    end
  end

  describe '#metadata_json_files' do
    subject(:metadata_json_files) { proc { described_object.metadata_json_files } }

    it 'returns metadata.json files' do
      expect(metadata_json_files.call).to eql(
        [
          '/usr/share/simp/modules/simplib/metadata.json',
          '/usr/share/simp/modules/stdlib/metadata.json'
        ]
      )
    end

    context 'when SIMP-installed modules directory is missing' do
      before(:each) { allow(File).to receive(:directory?).with(USR_MOD_DIR).and_return(false) }
      it { is_expected.to raise_error(RuntimeError, %r{Missing modules directory}) }
    end

    context 'when no metadata.json files are found' do
      before(:each) { allow(Dir).to receive(:[]).with(MDJ_FILES_GLOB).and_return([]) }
      it { is_expected.to raise_error(RuntimeError, %r{No modules with metadata\.json files found}) }
    end
  end

  describe '#metadata' do
    subject(:metadata) { proc { described_object.metadata(SINGLE_MDJ_FILE) } }

    it 'contains the expected metadata' do
      expect(metadata.call).to eql SINGLE_METADATA
    end

    context 'when a metadata.json file is missing (sanity check)' do
      before(:each) { allow(File).to receive(:exist?).with(SINGLE_MDJ_FILE).and_return(false) }
      it { is_expected.to raise_error(RuntimeError, %r{No metadata\.json file}) }
    end
  end

  describe '#modules' do
    subject(:modules) { described_object.modules }

    it { is_expected.to be_an Array }
    it { is_expected.not_to be_empty }
    it { expect(modules.first.to_s).to match %r{^mod 'simp-simplib',} }
  end

  describe '#timestamp' do
    it { expect(described_object.timestamp).to eql 'YYYY-mm-dd HH:MM:SSZ' }
  end

  describe '#to_puppetfile' do
    subject { described_object.to_puppetfile }

    expected_puppetfile = <<-PUPPETFILE.gsub(%r{^ {6}}, '')
      # ------------------------------------------------------------------------------
      # SIMP Puppetfile (Generated at YYYY-mm-dd HH:MM:SSZ)
      # ------------------------------------------------------------------------------
      # This Puppetfile deploys SIMP Puppet modules from the local git repositories
      # installed at /usr/share/simp/git/puppet_modules, referencing tagged git commits
      # that match the versions for each module installed in /usr/share/simp/modules.
      # ------------------------------------------------------------------------------

      mod 'simp-simplib',
        :git => 'file:///usr/share/simp/git/puppet_modules/simp-simplib.git',
        :version => '3.13.0'

      mod 'puppetlabs-stdlib',
        :git => 'file:///usr/share/simp/git/puppet_modules/puppetlabs-stdlib.git',
        :version => '5.2.0'
    PUPPETFILE

    it 'prints the expected Puppetfile' do
      puts subject if ENV['VERBOSE'] == 'yes'
      expect(subject).to include(expected_puppetfile)
    end
  end
end
