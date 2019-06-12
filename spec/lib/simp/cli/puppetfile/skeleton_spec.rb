require 'simp/cli/puppetfile/skeleton'
require 'spec_helper'
require 'test_utils/git'
require 'tmpdir'

describe Simp::Cli::Puppetfile::Skeleton do
  # Set up the following tree in a tmp dir
  #
  #  +-- local_repos           <- bare local repos
  #      +-- simplib.git
  #      +-- stdlib.git
  #  +-- environments_all_local_modules
  #      +-- testenv
  #          +-- modules
  #              +-- extra1
  #              +-- extra2
  #              +-- extra3   <- git project with no remote
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
      'all local modules' => {
        :environmentpath => File.join(@tmp_dir, 'environments_all_local_modules'),
        :modules_dir     => File.join(@tmp_dir, 'environments_all_local_modules', @puppet_env, 'modules')
      }
    }

    @environmentpaths.each_value { |paths| FileUtils.mkdir_p(paths[:modules_dir]) }

    # create local (bare) git repos that will be cloned in module paths
    test_files = File.join(__dir__, 'files')
    simplib_repo_dir = File.join(@local_repo_dir, 'simplib.git')
    TestUtils::Git::create_bare_repo(simplib_repo_dir, File.join(test_files, 'simplib', 'metadata.json'))
    stdlib_repo_dir = File.join(@local_repo_dir, 'stdlib.git')
    TestUtils::Git::create_bare_repo(stdlib_repo_dir, File.join(test_files, 'stdlib', 'metadata.json'))

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

          expect( Simp::Cli::Puppetfile::Skeleton.new(@puppet_env).to_puppetfile ).to eq expected_skeleton_only
        end
      end

      context 'when no local modules exist in the module path' do
        it 'should generate skeleton Puppetfile' do
          test_puppet_info = { :environment_path => @environmentpaths['no local modules'][:environmentpath] }
          allow(Simp::Cli::Utils).to receive(:puppet_info).with(@puppet_env).and_return(test_puppet_info)

          expect( Simp::Cli::Puppetfile::Skeleton.new(@puppet_env).to_puppetfile ).to eq expected_skeleton_only
        end
      end

      context 'when some local modules exist in the module path' do
        it 'should generate skeleton Puppetfile with local modules' do
          test_puppet_info = { :environment_path => @environmentpaths['some local modules'][:environmentpath] }
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


            #{Simp::Cli::Puppetfile::Skeleton::ROLES_PROFILES_SECTION}

          PUPPETFILE

          expect( Simp::Cli::Puppetfile::Skeleton.new(@puppet_env).to_puppetfile ).to eq expected
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

          expect( Simp::Cli::Puppetfile::Skeleton.new(@puppet_env).to_puppetfile ).to eq expected
        end
      end
    end

    context "when the 'git' command could not be found" do
      it 'should fail' do
        allow(Facter::Core::Execution).to receive(:which).and_return(nil)
        expect { Simp::Cli::Puppetfile::Skeleton.new(@puppet_env).to_puppetfile }.to raise_error(
          Simp::Cli::ProcessingError, /Could not find 'git' command/
        )
      end
    end

  end
end
