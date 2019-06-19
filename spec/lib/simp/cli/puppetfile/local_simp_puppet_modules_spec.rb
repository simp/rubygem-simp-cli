require 'simp/cli/puppetfile/local_simp_puppet_modules'
require 'spec_helper'
require 'test_utils/git'

describe Simp::Cli::Puppetfile::LocalSimpPuppetModules do

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
    @modules_install_dir = File.join(@tmp_dir, 'modules')
    @modules_git_dir = File.join(@tmp_dir, 'git', 'puppet_modules')
    FileUtils.mkdir_p(@modules_git_dir)

    test_modules.each do |module_name, info|
      module_install_dir = File.join(@modules_install_dir, module_name)
      FileUtils.mkdir_p(module_install_dir)
      FileUtils.cp(info[:metadata_file], module_install_dir)

      module_git_dir = File.join(@modules_git_dir, "#{info[:metadata]['name']}.git")
      TestUtils::Git::create_bare_repo(module_git_dir, info[:metadata_file], info[:git_tags])
    end
  end

  after(:all) do
    FileUtils.remove_entry_secure @tmp_dir
  end

  before(:each) do
    allow(Simp::Cli::Utils).to receive(:timestamp).and_return('YYYY-mm-dd HH:MM:SS')
    @local_modules = described_class.new(@modules_install_dir, @modules_git_dir)
  end

  describe '#metadata_json_files' do

    it 'returns metadata.json files' do
      expect( @local_modules.metadata_json_files.sort ).to eq(
        [
          "#{@modules_install_dir}/simplib/metadata.json",
          "#{@modules_install_dir}/stdlib/metadata.json"
        ]
      )
    end

    context 'when SIMP-installed modules directory is missing' do
      it do
        local_modules = described_class.new('/missing/modules', @modules_git_dir)
        expect { local_modules.metadata_json_files }.to raise_error(
          Simp::Cli::ProcessingError, %r{Missing modules directory at '\/missing\/modules'}
        )
      end
    end

    context 'when no metadata.json files are found' do
      it do
        modules_install_dir = File.join(@tmp_dir, 'empty_modules')
        FileUtils.mkdir(modules_install_dir)
        local_modules = described_class.new(modules_install_dir, @modules_git_dir)

        expect { local_modules.metadata_json_files }.to raise_error(
          Simp::Cli::ProcessingError,
          %r{No modules with metadata\.json files found in '.*empty_modules'}
        )
      end
    end
  end

  describe '#metadata' do
    it 'contains the expected metadata' do
       mdj_file = test_modules.first[1][:metadata_file]
       metadata = test_modules.first[1][:metadata]
      expect( @local_modules.metadata(mdj_file) ).to eq metadata
    end

    context 'when a metadata.json file is missing (sanity check)' do
      it do
        expect { @local_modules.metadata('/removed/metadata.json') }.to raise_error(
          Simp::Cli::ProcessingError,
          %r{'\/removed\/metadata.json' does not exist}
        )
      end
    end
  end

  describe '#modules' do
    context 'when only valid modules are found in RPM install path' do
      it { expect( @local_modules.modules).to be_an Array }
      it { expect( @local_modules.modules.length).to be test_modules.keys.length }
      it { expect( @local_modules.modules.sort{|a,b| a.to_s <=> b.to_s }.first.to_s).to match %r{^mod 'puppetlabs-stdlib',} }
    end

    context 'when invalid modules found in RPM install path' do
      before(:each) do
        # create a module in the RPM install path for which there is
        # no git repo
        module_install_dir = File.join(@modules_install_dir, 'extra1')
        FileUtils.mkdir(module_install_dir)

        metadata_file = File.join(test_files, 'extra1', 'metadata.json')
        FileUtils.cp(metadata_file, File.join(module_install_dir, 'metadata.json'))
      end

      it 'fails when bad modules ignore_bad_modules=false' do
        local_modules = described_class.new(@modules_install_dir, @modules_git_dir, false)
        expect { local_modules.modules }.to raise_error(
          Simp::Cli::ProcessingError,
          %r{Missing local git repository}
        )
      end

      it 'skips the bad module when ignore_bad_modules=true' do
        # This is the default behavior
        expect( @local_modules.modules.length ).to be test_modules.keys.length
      end

      after(:each) do
        FileUtils.rm_rf(File.join(@modules_install_dir, 'extra1'))
      end
    end
  end


  describe '#to_puppetfile' do
    it 'prints the expected Puppetfile' do
      expected_puppetfile = <<-PUPPETFILE.gsub(%r{^ {8}}, '')
        # ------------------------------------------------------------------------------
        # SIMP Puppetfile (Generated at YYYY-mm-dd HH:MM:SS)
        # ------------------------------------------------------------------------------
        # This Puppetfile deploys SIMP Puppet modules from the local Git repositories at
        #   #{@modules_git_dir}
        # referencing tagged Git commits that match the versions for each module
        # installed in
        #   #{@modules_install_dir}
        #
        # The Git repositories are automatically created and updated when SIMP module
        # RPMs are installed.
        # ------------------------------------------------------------------------------

        mod 'puppetlabs-stdlib',
          :git => 'file://#{@modules_git_dir}/puppetlabs-stdlib.git',
          :tag => '5.2.0'

        mod 'simp-simplib',
          :git => 'file://#{@modules_git_dir}/simp-simplib.git',
          :tag => '3.13.0'

      PUPPETFILE

      puts @local_modules.to_puppetfile if ENV['VERBOSE'] == 'yes'
      expect(@local_modules.to_puppetfile).to eq expected_puppetfile
    end
  end
end
