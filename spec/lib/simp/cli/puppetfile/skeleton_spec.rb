require 'simp/cli/puppetfile/skeleton'
require 'spec_helper'
require 'test_utils/git'
require 'tmpdir'

describe Simp::Cli::Puppetfile::Skeleton do
  # Set up the following tree in a tmp dir
  #
  #  +-- local_repos           <- bare local repos
  #      +-- simp-simplib.git
  #      +-- puppetlabs-stdlib.git
  #      +-- saz-timezone.git
  #  +-- environments_all_local_modules
  #      +-- testenv
  #          +-- modules
  #              +-- extra1
  #              +-- extra2
  #              +-- extra3   <- git project with no remote
  #  +-- environments_local_modules_with_duplicates
  #      +-- testenv
  #          +-- modules
  #              +-- extra1
  #              +-- extra2
  #              +-- simplib  <- no git but matches local_repos
  #              +-- stdlib   <- no git but matches local_repos
  #  +-- environments_local_modules_with_obsoletes
  #      +-- testenv
  #          +-- modules
  #              +-- extra1
  #              +-- extra2
  #              +-- timezone <- simp-timezone obsoleted by saz-timezone
  #  +-- environments_no_local_modules
  #      +-- testenv
  #          +-- modules
  #              +-- simplib  <- git clone
  #              +-- stdlib   <- git clone
  #  +-- environments_no_modules
  #      +-- testenv
  #          +-- modules
  #  +-- environments_some_local_modules
  #      +-- testenv
  #          +-- modules
  #              +-- extra1
  #              +-- extra2
  #              +-- simplib  <- git clone
  #              +-- stdlib   <- git clone
  #
  before(:all) do
    @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
    @local_repo_dir         =  File.join(@tmp_dir, 'local_repos')
    @puppet_env             = 'testenv'
    @environmentpaths = {
      'no modules'=> {
        :environmentpath => File.join(@tmp_dir, 'environments_no_modules'),
        :modules_dir     => File.join(@tmp_dir, 'environments_no_modules', @puppet_env, 'modules')
      },
      'no local modules' => {
        :environmentpath => File.join(@tmp_dir, 'environments_no_local_modules'),
        :modules_dir     => File.join(@tmp_dir, 'environments_no_local_modules', @puppet_env, 'modules')
      },
      'some local modules' => {
        :environmentpath => File.join(@tmp_dir, 'environments_some_local_modules'),
        :modules_dir     => File.join(@tmp_dir, 'environments_some_local_modules', @puppet_env, 'modules')
      },
      'local modules with duplicates' => {
        :environmentpath => File.join(@tmp_dir, 'environments_local_modules_with_duplicates'),
        :modules_dir     => File.join(@tmp_dir, 'environments_local_modules_with_duplicates', @puppet_env, 'modules')
      },
      'local modules with obsoletes' => {
        :environmentpath => File.join(@tmp_dir, 'environments_local_modules_with_obsoletes'),
        :modules_dir     => File.join(@tmp_dir, 'environments_local_modules_with_obsoletes', @puppet_env, 'modules')
      },
      'all local modules' => {
        :environmentpath => File.join(@tmp_dir, 'environments_all_local_modules'),
        :modules_dir     => File.join(@tmp_dir, 'environments_all_local_modules', @puppet_env, 'modules')
      }
    }

    @environmentpaths.each_value { |paths| FileUtils.mkdir_p(paths[:modules_dir]) }

    # create local (bare) git repos that will be cloned in module paths or
    # used for obsolete module evaluation
    test_files = File.join(__dir__, 'files')
    simplib_repo_dir = File.join(@local_repo_dir, 'simp-simplib.git')
    TestUtils::Git::create_bare_repo(simplib_repo_dir, File.join(test_files, 'simplib', 'metadata.json'))
    stdlib_repo_dir = File.join(@local_repo_dir, 'puppetlabs-stdlib.git')
    TestUtils::Git::create_bare_repo(stdlib_repo_dir, File.join(test_files, 'stdlib', 'metadata.json'))
    timezone_repo_dir = File.join(@local_repo_dir, 'saz-timezone.git')
    TestUtils::Git::create_bare_repo(timezone_repo_dir, File.join(test_files, 'saz-timezone', 'metadata.json'))

    # clone into module paths
    TestUtils::Git::clone_local_module_repo(simplib_repo_dir, @environmentpaths['no local modules'][:modules_dir])
    TestUtils::Git::clone_local_module_repo(stdlib_repo_dir, @environmentpaths['no local modules'][:modules_dir])
    TestUtils::Git::clone_local_module_repo(simplib_repo_dir, @environmentpaths['some local modules'][:modules_dir])
    TestUtils::Git::clone_local_module_repo(stdlib_repo_dir, @environmentpaths['some local modules'][:modules_dir])

    # create a local module under Git control but for which no remote exists
    FileUtils.cp_r(File.join(test_files, 'extra3/'), @environmentpaths['all local modules'][:modules_dir])
    Dir.chdir(File.join(@environmentpaths['all local modules'][:modules_dir], 'extra3')) do
      TestUtils::Git::run_command('git init')
      TestUtils::Git::run_command('git add --all')
      TestUtils::Git::run_command("git commit -m 'initial commit'")
    end

    # create local modules not under Git control
    FileUtils.cp_r(File.join(test_files, 'extra1'), @environmentpaths['all local modules'][:modules_dir])
    FileUtils.cp_r(File.join(test_files, 'extra2'), @environmentpaths['all local modules'][:modules_dir])
    FileUtils.cp_r(File.join(test_files, 'extra1'), @environmentpaths['some local modules'][:modules_dir])
    FileUtils.cp_r(File.join(test_files, 'extra2'), @environmentpaths['some local modules'][:modules_dir])
    FileUtils.cp_r(File.join(test_files, 'extra1'), @environmentpaths['local modules with duplicates'][:modules_dir])
    FileUtils.cp_r(File.join(test_files, 'extra2'), @environmentpaths['local modules with duplicates'][:modules_dir])
    FileUtils.cp_r(File.join(test_files, 'simplib'), @environmentpaths['local modules with duplicates'][:modules_dir])
    FileUtils.cp_r(File.join(test_files, 'stdlib'), @environmentpaths['local modules with duplicates'][:modules_dir])
    FileUtils.cp_r(File.join(test_files, 'extra1'), @environmentpaths['local modules with obsoletes'][:modules_dir])
    FileUtils.cp_r(File.join(test_files, 'extra2'), @environmentpaths['local modules with obsoletes'][:modules_dir])
    FileUtils.cp_r(File.join(test_files, 'saz-timezone'), File.join(@environmentpaths['local modules with obsoletes'][:modules_dir], 'saz'))
  end

  after(:all) do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe '.to_puppetfile' do
    let(:expected_skeleton_only) do
      <<-PUPPETFILE.gsub(/ {8}/,'')
        #{Simp::Cli::Puppetfile::Skeleton::INTRO_SECTION}
        instance_eval(File.read(File.join(__dir__,"Puppetfile.simp")))


        #{Simp::Cli::Puppetfile::Skeleton::LOCAL_MODULE_SECTION}



        #{Simp::Cli::Puppetfile::Skeleton::ROLES_PROFILES_SECTION}

      PUPPETFILE
    end

    let(:expected_skeleton_with_extras) do
      <<-PUPPETFILE.gsub(/ {8}/,'')
        # ==============================================================================
        # Puppetfile (Generated at YYYY-mm-dd HH:MM:SS with local modules from
        # 'testenv' Puppet environment)
        #
        #{Simp::Cli::Puppetfile::Skeleton::INTRO_SECTION}
        instance_eval(File.read(File.join(__dir__,"Puppetfile.simp")))


        #{Simp::Cli::Puppetfile::Skeleton::LOCAL_MODULE_SECTION}
        mod 'extra1', :local => true
        mod 'extra2', :local => true


        #{Simp::Cli::Puppetfile::Skeleton::ROLES_PROFILES_SECTION}

      PUPPETFILE
    end


    context 'when no environment is specified' do
      context 'when no local modules exist in the module path' do
        it 'should generate skeleton Puppetfile' do
          expect( Simp::Cli::Puppetfile::Skeleton.new.to_puppetfile ).to eq expected_skeleton_only
        end
      end

      context 'when local modules exist in the module path' do
        it 'should generate skeleton Puppetfile without local modules' do
          expect( Simp::Cli::Puppetfile::Skeleton.new.to_puppetfile ).to eq expected_skeleton_only
        end
      end
    end

    context 'when an environment is specified' do
      before(:each) do
        allow(Simp::Cli::Utils).to receive(:timestamp).and_return('YYYY-mm-dd HH:MM:SS')
      end

      context 'when no modules exist in the module path' do
        it 'should generate skeleton Puppetfile' do
          test_puppet_info = { :environment_path => @environmentpaths['no modules'][:environmentpath] }
          allow(Simp::Cli::Utils).to receive(:puppet_info).with(@puppet_env).and_return(test_puppet_info)

          expect( Simp::Cli::Puppetfile::Skeleton.new(@puppet_env, '/does/not/exist').to_puppetfile ).to eq expected_skeleton_only
        end
      end

      context 'when no local modules exist in the module path' do
        it 'should generate skeleton Puppetfile' do
          test_puppet_info = { :environment_path => @environmentpaths['no local modules'][:environmentpath] }
          allow(Simp::Cli::Utils).to receive(:puppet_info).with(@puppet_env).and_return(test_puppet_info)

          expect( Simp::Cli::Puppetfile::Skeleton.new(@puppet_env, '/does/not/exist').to_puppetfile ).to eq expected_skeleton_only
        end
      end

      context 'when some local modules exist in the module path' do
        it 'should generate skeleton Puppetfile with local modules' do
          test_puppet_info = { :environment_path => @environmentpaths['some local modules'][:environmentpath] }
          allow(Simp::Cli::Utils).to receive(:puppet_info).with(@puppet_env).and_return(test_puppet_info)

          expect( Simp::Cli::Puppetfile::Skeleton.new(@puppet_env, '/does/not/exist').to_puppetfile ).to eq expected_skeleton_with_extras
        end
      end

      context 'when local modules with duplicates to local Git repos exist in the module path' do
        it 'should generate skeleton Puppetfile with non-duplicate local modules' do
          test_puppet_info = { :environment_path => @environmentpaths['local modules with duplicates'][:environmentpath] }
          allow(Simp::Cli::Utils).to receive(:puppet_info).with(@puppet_env).and_return(test_puppet_info)

          expect( Simp::Cli::Puppetfile::Skeleton.new(@puppet_env, @local_repo_dir).to_puppetfile ).to eq expected_skeleton_with_extras
        end
      end

      context 'when local modules that have been obsoleted by local Git repos exist in the module path' do
        it 'should generate skeleton Puppetfile with non-obsoleted local modules' do
          test_puppet_info = { :environment_path => @environmentpaths['local modules with obsoletes'][:environmentpath] }
          allow(Simp::Cli::Utils).to receive(:puppet_info).with(@puppet_env).and_return(test_puppet_info)
          generator =  Simp::Cli::Puppetfile::Skeleton.new(@puppet_env, @local_repo_dir)
          query_result = <<-EOM
pupmod-simp-timezone < 5.0.3-0.obsolete
pupmod-timezone < 5.1.1-0
saz-timezone < 5.1.1-0
          EOM
          allow(generator).to receive(:`).with('rpm -q pupmod-saz-timezone').and_return(query_result)

          expect( generator.to_puppetfile ).to eq expected_skeleton_with_extras
        end
      end

      context 'when all local modules exist in the module path' do
        it 'should generate skeleton Puppetfile with local modules' do
          test_puppet_info = { :environment_path => @environmentpaths['all local modules'][:environmentpath] }
          allow(Simp::Cli::Utils).to receive(:puppet_info).with(@puppet_env).and_return(test_puppet_info)

          expected = <<-PUPPETFILE.gsub(/ {12}/,'')
            # ==============================================================================
            # Puppetfile (Generated at YYYY-mm-dd HH:MM:SS with local modules from
            # 'testenv' Puppet environment)
            #
            #{Simp::Cli::Puppetfile::Skeleton::INTRO_SECTION}
            instance_eval(File.read(File.join(__dir__,"Puppetfile.simp")))


            #{Simp::Cli::Puppetfile::Skeleton::LOCAL_MODULE_SECTION}
            mod 'extra1', :local => true
            mod 'extra2', :local => true
            mod 'extra3', :local => true


            #{Simp::Cli::Puppetfile::Skeleton::ROLES_PROFILES_SECTION}

          PUPPETFILE

          expect( Simp::Cli::Puppetfile::Skeleton.new(@puppet_env, '/does/not/exist').to_puppetfile ).to eq expected
        end
      end
    end

    context "when the 'git' command could not be found" do
      it 'should fail' do
        allow(Facter::Core::Execution).to receive(:which).and_return(nil)
        expect { Simp::Cli::Puppetfile::Skeleton.new(@puppet_env, '/does/not/exist').to_puppetfile }.to raise_error(
          Simp::Cli::ProcessingError, /Could not find 'git' command/
        )
      end
    end
  end

  describe '.load_metadata' do
    let (:test_files) { File.join(__dir__, 'files') }

    it 'should return metadata Hash when metadata.json is valid' do
      generator = Simp::Cli::Puppetfile::Skeleton.new
      expected = {
        "author"                  => "Local Team",
        "dependencies"            => [],
        "issues_url"              => "https://simp-project.atlassian.net",
        "license"                 => "Apache-2.0",
        "name"                    => "local-extra1",
        "operatingsystem_support" => [
          {
            "operatingsystem"        => "CentOS",
            "operatingsystemrelease" => ["6", "7"]
          }
        ],
        "project_page"            => "https://github.com/simp/pupmod-simp-extra1",
        "requirements"            => [
          {
            "name"                => "puppet",
            "version_requirement" => ">= 4.10.4 < 7.0.0"
          }
        ],
        "source"                  => "https://github.com/simp/pupmod-simp-extra1",
        "summary"                 => "Local extra test module 1",
        "tags"                    => [],
        "version"                 => "1.0.0"
      }

      # .send() to work around private method...
      expect( generator.send(:load_metadata, File.join(test_files, 'extra1')) ).to eq expected
    end

    it 'should return nil Hash when metadata.json does not exist' do
      generator = Simp::Cli::Puppetfile::Skeleton.new
      expect( generator.send(:load_metadata, '/does/not/exist/module') ).to be_nil
      expect{ generator.send(:load_metadata, '/does/not/exist/module') }.to output(
        "Ignoring local module /does/not/exist/module: metadata.json missing\n"
      ).to_stderr
    end

    it 'should return nil Hash when metadata.json is malformed' do
      module_dir = File.join(test_files, 'malformed_metadata')
      generator = Simp::Cli::Puppetfile::Skeleton.new
      expect( generator.send(:load_metadata, module_dir) ).to be_nil
      expect{ generator.send(:load_metadata, module_dir) }.to output(
        /Ignoring local module #{Regexp.escape(module_dir)}/
      ).to_stderr
    end

    it "should return nil Hash when metadata.json is missing top-level 'name' key" do
      module_dir = File.join(test_files, 'missing_name_metadata')
      generator = Simp::Cli::Puppetfile::Skeleton.new
      expect( generator.send(:load_metadata, module_dir) ).to be_nil
      expect{ generator.send(:load_metadata, module_dir) }.to output(
        "Ignoring local module #{module_dir}: 'name' missing from metadata.json\n"
      ).to_stderr
    end
  end

end
