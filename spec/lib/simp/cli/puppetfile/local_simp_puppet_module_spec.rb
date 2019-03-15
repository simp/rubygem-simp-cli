require 'simp/cli/puppetfile/local_simp_puppet_module'
require 'spec_helper'

describe Simp::Cli::Puppetfile::LocalSimpPuppetModule do
  TEST_FILES = File.join(__dir__, 'files')

  # Mock data about 1..n modules
  USR_MOD_DIR  = '/usr/share/simp/modules'.freeze
  SIMP_GIT_DIR = '/usr/share/simp/git/puppet_modules'.freeze
  TEST_MODULES = Hash[
    %w[simplib stdlib].map do |k|
      mdj_str = File.read(File.join(TEST_FILES, "#{k}.metadata.json"))
      [k, {
        :metadata_json_path => "#{USR_MOD_DIR}/#{k}/metadata.json",
        :metadata_json_str => mdj_str,
        :git_tag_l_str => File.read(File.join(TEST_FILES, "#{k}.git_tag_-l.txt")),
        :metadata => JSON.parse(mdj_str)
      }]
    end
  ]

  before(:each) do
    # Pass through partial mocks when we don't need them
    allow(File).to receive(:directory?).with(any_args).and_call_original
    allow(File).to receive(:exist?).with(any_args).and_call_original
    allow(File).to receive(:read).with(any_args).and_call_original
    allow(Dir).to receive(:[]).with(any_args).and_call_original
    allow(Dir).to receive(:chdir).with(any_args).and_call_original
    allow(File).to receive(:directory?).with(SIMP_GIT_DIR).and_yield(SIMP_GIT_DIR)
  end

  TEST_MODULES.each do |_k, v|
    let(:metadata) { v[:metadata] }
    let(:module_git_dir) { File.join(SIMP_GIT_DIR, "#{v[:metadata]['name']}.git") }
    let(:git_tag_l_str) { v[:git_tag_l_str] }
    context "with module '#{v[:metadata]['name']}'" do
      subject(:described_object) { described_class.new(metadata, SIMP_GIT_DIR) }

      before(:each) do
        allow(Dir).to receive(:chdir).with(module_git_dir).and_yield(module_git_dir)
        allow(File).to receive(:directory?).with(module_git_dir).and_return(true)
      end

      describe '#initialize' do
        subject(:object_init) { proc { described_object } }

        it { is_expected.not_to raise_error }

        context 'with non-module metadata' do
          let(:metadata) { {} }

          it { is_expected.to raise_error(RuntimeError, %r{Could not read 'name' from module metadata}) }
        end

        context 'with non-Hash metadata' do
          let(:metadata) { '' }

          it { is_expected.to raise_error(RuntimeError, %r{Could not read 'name' from module metadata}) }
        end
      end

      describe '#local_git_repo_path' do
        subject(:local_git_repo_path) { proc { described_object.local_git_repo_path } }

        it { is_expected.not_to raise_error }

        context 'with missing git repo directory' do
          let(:module_git_dir) { File.join(SIMP_GIT_DIR, 'no_such_directory.git') }

          it { is_expected.to raise_error(RuntimeError, %r{Missing local git repository}) }
        end
      end

      describe '#tag_exists_for_version?' do
        subject(:tag_exists_for_version?) { proc { described_object.tag_exists_for_version? } }

        before(:each) do
          allow(described_object).to receive(:`).with('git tag -l').and_return(git_tag_l_str)
        end

        it { is_expected.not_to raise_error }

        context "when the repo doesn't include a matching tag" do
          before(:each) do
            allow(described_object).to receive(:`).with('git tag -l').and_return("0.0.0\n1.0.0-pre1\n")
          end

          it { is_expected.to raise_error(RuntimeError, %r{Tag '.*' not found}) }
        end
      end

      describe '#to_s' do
        subject(:to_s) { described_object.to_s }

        before(:each) { described_object.instance_variable_set :@data, metadata }

        it 'returns the expected Puppetfile entry' do
          expect(to_s).to eql <<-MOD_ENTRY.gsub(%r{^ {12}}, '')
            mod '#{metadata['name']}',
              :git => '#{module_git_dir}',
              :tag => '#{metadata['version']}'

          MOD_ENTRY
        end
      end
    end
  end
end
