require 'simp/cli/puppetfile/local_simp_puppet_module'
require 'spec_helper'
require 'test_utils/git'
require 'tmpdir'

describe Simp::Cli::Puppetfile::LocalSimpPuppetModule do

  # Mock module data
  test_files   = File.join(__dir__, 'files')
  test_modules = Hash[
    %w[simplib stdlib].map do |k|
      [k, {
        :metadata_file => File.join(test_files, k, 'metadata.json'),
        :metadata      => JSON.parse(File.read(File.join(test_files, k, 'metadata.json'))),
        :git_tags      => File.readlines(File.join(test_files, k, 'git_tag_-l.txt')).map(&:strip)
      }]
    end
  ]

  before(:all) do
    @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
    test_modules.each do |module_name, info|
      module_git_dir = File.join(@tmp_dir, "#{info[:metadata]['name']}.git")
      TestUtils::Git::create_bare_repo(module_git_dir, info[:metadata_file], info[:git_tags])
    end
  end

  after(:all) do
    FileUtils.remove_entry_secure @tmp_dir
  end

  test_modules.each_value do |v|
    context "with module '#{v[:metadata]['name']}'" do
      let(:metadata) { v[:metadata] }
      let(:module_git_dir) { File.join(@tmp_dir, "#{v[:metadata]['name']}.git") }


      describe '#initialize' do
        it { expect { described_class.new(metadata, @tmp_dir) }.not_to raise_error }

        context 'with non-module metadata' do
          let(:metadata) { {} }

          it do
            expect { described_class.new(metadata, @tmp_dir) }.to raise_error(
              Simp::Cli::Puppetfile::ModuleError,
              %r{Could not read 'name' from module metadata}
            )
          end
        end

        context 'with non-Hash metadata' do
          let(:metadata) { '' }

           it do
            expect { described_class.new(metadata, @tmp_dir) }.to raise_error(
              Simp::Cli::Puppetfile::ModuleError,
              %r{Could not read 'name' from module metadata}
            )
          end
        end

        context 'when local git repo does not exists' do
          before(:each) do
            FileUtils.mv(module_git_dir, "#{module_git_dir}.bak")
          end

          it do
            expect { described_class.new(metadata, @tmp_dir) }.to raise_error(
              Simp::Cli::Puppetfile::ModuleError,
              %r{Missing local git repository}
            )
          end

          after(:each) do
            FileUtils.mv("#{module_git_dir}.bak", module_git_dir)
          end
        end

        context 'when tag does not exist' do
           let(:metadata) { v[:metadata].merge( {'version' => '9.9.9'} ) }
          it do
            expect { described_class.new(metadata, @tmp_dir) }.to raise_error(
              Simp::Cli::Puppetfile::ModuleError, %r{Tag '9.9.9' not found}
            )
          end
        end
      end

      describe '#to_s' do
        it 'returns the expected Puppetfile entry' do
          expect( described_class.new(metadata, @tmp_dir).to_s ).to eql <<-MOD_ENTRY.gsub(%r{^ {12}}, '')
            mod '#{metadata['name']}',
              :git => 'file://#{module_git_dir}',
              :tag => '#{metadata['version']}'
          MOD_ENTRY
        end
      end
    end
  end
end
