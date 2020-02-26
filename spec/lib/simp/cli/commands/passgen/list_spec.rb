require 'simp/cli/commands/passgen'
require 'simp/cli/commands/passgen/list'
require 'simp/cli/passgen/legacy_password_manager'
require 'simp/cli/passgen/password_manager'

require 'etc'
require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Commands::Passgen::List do
  before :each do
    @tmp_dir   = Dir.mktmpdir(File.basename(__FILE__))
    @var_dir = File.join(@tmp_dir, 'vardir')
    @puppet_env_dir = File.join(@tmp_dir, 'environments')
    @user  = Etc.getpwuid(Process.uid).name
    @group = Etc.getgrgid(Process.gid).name
    puppet_info = {
      :config => {
        'user'            => @user,
        'group'           => @group,
        'environmentpath' => @puppet_env_dir,
        'vardir'          => @var_dir
      }
    }

    # expose HighLine input and output for test validation
    @input = StringIO.new
    @output = StringIO.new
    @prev_terminal = $terminal
    $terminal = HighLine.new(@input, @output)

    allow(Simp::Cli::Utils).to receive(:puppet_info).and_return(puppet_info)
    @lister = Simp::Cli::Commands::Passgen::List.new

    # make sure notice and above messages are output
    @lister.set_up_global_logger
  end

  after :each do
    @input.close
    @output.close
    $terminal = @prev_terminal
    FileUtils.remove_entry_secure @tmp_dir, true
  end

  let(:module_list_old_simplib) {
    <<~EOM
      /etc/puppetlabs/code/environments/production/modules
      ├── puppet-yum (v3.1.1)
      ├── puppetlabs-stdlib (v5.2.0)
      ├── simp-aide (v6.3.0)
      ├── simp-simplib (v3.15.3)
      /var/simp/environments/production/site_files
      ├── krb5_files (???)
      └── pki_files (???)
      /etc/puppetlabs/code/modules (no modules installed)
      /opt/puppetlabs/puppet/modules (no modules installed)
    EOM
  }

  let(:module_list_new_simplib) {
    module_list_old_simplib.gsub(/simp-simplib .v3.15.3/,'simp-simplib (v4.0.0)')
  }

  let(:module_list_no_simplib) {
    list = module_list_old_simplib.dup.split("\n")
    list.delete_if { |line| line.include?('simp-simplib') }
    list.join("\n") + "\n"
  }

  let(:missing_deps_warnings) {
    <<~EOM
      Warning: Missing dependency 'puppetlabs-apt':
        'puppetlabs-postgresql' (v5.12.1) requires 'puppetlabs-apt' (>= 2.0.0 < 7.0.0)
    EOM
  }

  #
  # Custom Method Tests
  #
  describe '#show_name_list' do
    it 'reports no password names when list is empty' do
      mock_manager = object_double('Mock Password Manager', {
        :name_list => [],
        :location  => "'production' Environment"
      })

      expected_output =<<~EOM
        Retrieving password names... done.

        No passwords found in 'production' Environment

      EOM

      @lister.show_name_list(mock_manager)
      expect( @output.string ).to eq(expected_output)
    end

    it 'lists available password names' do
      mock_manager = object_double('Mock Password Manager', {
        :name_list => [ 'name1', 'name2', 'name3'],
        :location  => "'production' Environment"
      })

      expected_output = <<~EOM
        Retrieving password names... done.

        'production' Environment Password Names
        =======================================
        name1
        name2
        name3

      EOM

      @lister.show_name_list(mock_manager)
      expect( @output.string ).to eq(expected_output)
    end

    it 'fails when password list operation fails' do
      mock_manager = object_double('Mock Password Manager', {
        :name_list => nil,
        :location  => "'production' Environment"
      })

      allow(mock_manager).to receive(:name_list).and_raise(
        Simp::Cli::ProcessingError, 'List failed: connection timed out')

      expect { @lister.show_name_list(mock_manager) }.to raise_error(
        Simp::Cli::ProcessingError,
        "List for 'production' Environment failed: " +
        'List failed: connection timed out')
    end
  end

  #
  # Simp::Cli::Commands::Command API methods
  #
  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Passgen::List.description}/
      expect{ @lister.help }.to output(expected_stdout_regex).to_stdout
    end
  end

  describe '#run' do
    before :each do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'dev'))

      @module_list_command_prod =
        'puppet module list --color=false --environment=production'

      @module_list_command_dev =
        'puppet module list --color=false --environment=dev'

      @old_simplib_module_list_results = {
        :status => true,
        :stdout => module_list_old_simplib,
        :stderr => missing_deps_warnings
      }

      @new_simplib_module_list_results = {
        :status => true,
        :stdout => module_list_new_simplib,
        :stderr => missing_deps_warnings
      }

    end

    describe 'setup error cases for options using a password manager' do
      it 'fails when the environment does not exist' do
        expect { @lister.run(['-e', 'oops']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Invalid Puppet environment 'oops': Does not exist")
      end

      it 'fails when the environment does not have simp-simplib installed' do
        module_list_results = {
          :status => true,
          :stdout => module_list_no_simplib,
          :stderr => missing_deps_warnings
        }
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(@module_list_command_prod, false, @lister.logger)
          .and_return(module_list_results)

        expect { @lister.run([]) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Invalid Puppet environment 'production': " +
          'simp-simplib is not installed')
      end

      it 'fails when LegacyPasswordManager cannot be constructed' do
        allow(@lister).to receive(:get_simplib_version).and_return('3.0.0')
        password_env_dir = File.join(@var_dir, 'simp', 'environments')
        default_password_dir = File.join(password_env_dir, 'production',
          'simp_autofiles', 'gen_passwd')

        FileUtils.mkdir_p(File.dirname(default_password_dir))
        FileUtils.touch(default_password_dir)
        expect { @lister.run([]) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{default_password_dir}' is not a directory")
      end
    end

    # This test verifies that the correct password manager object has been
    # instantiated and used in Simp::Cli::Commands::Passgen::List#show_name_list.
    describe 'using password manager' do
      context 'legacy manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @lister.logger)
            .and_return(@old_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @lister.logger)
            .and_return(@old_simplib_module_list_results)
        end

        it 'lists available names for default environment' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :name_list => [ 'name1', 'name2' ],
            :location  => "'production' Environment"
          })

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', nil).and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Retrieving password names... done.

            'production' Environment Password Names
            =======================================
            name1
            name2

          EOM

          @lister.run([])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists available names for specified environment' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :name_list => [ 'name1' ],
            :location  => "'dev' Environment"
          })

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('dev', nil).and_return(mock_manager)
          expected_output = <<~EOM
            Initializing for environment 'dev'... done.
            Retrieving password names... done.

            'dev' Environment Password Names
            ================================
            name1

          EOM

          @lister.run(['-e', 'dev'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists available names for specified directory' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :name_list => [ 'name1' ],
            :location  => '/some/passgen/path'
          })

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', '/some/passgen/path').and_return(mock_manager)
          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Retrieving password names... done.

            /some/passgen/path Password Names
            =================================
            name1

          EOM

          @lister.run(['-d', '/some/passgen/path'])
          expect( @output.string ).to eq(expected_output)
        end

      end

      context 'current manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @lister.logger)
            .and_return(@new_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @lister.logger)
            .and_return(@new_simplib_module_list_results)
        end

        it 'lists available names for the top folder of the default env' do
          mock_manager = object_double('Mock PasswordManager', {
            :name_list => [ 'name1', 'name2' ],
            :location  => "'production' Environment"
          })

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('production', nil, nil).and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Retrieving password names... done.

            'production' Environment Password Names
            =======================================
            name1
            name2

          EOM

          @lister.run([])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists available names for the specified <env,folder,backend>' do
          mock_manager = object_double('Mock PasswordManager', {
            :name_list => [ 'name1' ],
            :location  =>
              "'dev' Environment, 'folder1' Folder, 'backend3' simpkv Backend"
          })

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('dev', 'backend3', 'folder1').and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'dev'... done.
            Retrieving password names... done.

            'dev' Environment, 'folder1' Folder, 'backend3' simpkv Backend Password Names
            ============================================================================
            name1

          EOM

          @lister.run(['-e', 'dev', '--folder', 'folder1',
            '--backend', 'backend3'])

          expect( @output.string ).to eq(expected_output)
        end
      end
    end
  end
end
