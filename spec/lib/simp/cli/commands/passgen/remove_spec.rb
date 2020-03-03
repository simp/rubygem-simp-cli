require 'simp/cli/commands/passgen'
require 'simp/cli/commands/passgen/remove'
require 'simp/cli/passgen/legacy_password_manager'
require 'simp/cli/passgen/password_manager'

require 'etc'
require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Commands::Passgen::Remove do
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
    @remover = Simp::Cli::Commands::Passgen::Remove.new

    # make sure notice and above messages are output
    @remover.set_up_global_logger
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
  describe '#remove_passwords' do
    before :each do
    end

    let(:names) { [ 'name1', 'name2', 'name3', 'name4' ] }

    it 'removes passwords when force_remove=false & prompt returns yes' do
      allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)

      # mock the password manager with a double of String in which methods
      # needed have been defined
      mock_manager = object_double('Mock Password Manager', {
        :remove_password => nil,
        :location        => "'production' Environment"
      })

      expected_output = <<~EOM
        Processing 'name1' in 'production' Environment... done.
          Removed 'name1'

        Processing 'name2' in 'production' Environment... done.
          Removed 'name2'

        Processing 'name3' in 'production' Environment... done.
          Removed 'name3'

        Processing 'name4' in 'production' Environment... done.
          Removed 'name4'

      EOM

      @remover.remove_passwords(mock_manager, names, false)
      expect( @output.string ).to eq(expected_output)
    end

    it 'does not remove passwords when force_remove=false & prompt returns no' do
      allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(false)
      mock_manager = object_double('Mock Password Manager', {
        :remove_password => nil,
        :location        => "'production' Environment"
      })
      expected_output = <<~EOM
        Skipped 'name1' in 'production' Environment

        Skipped 'name2' in 'production' Environment

        Skipped 'name3' in 'production' Environment

        Skipped 'name4' in 'production' Environment

      EOM

      @remover.remove_passwords(mock_manager, names, false)
      expect( @output.string ).to eq(expected_output)
    end

    it 'removes password names when force_remove=true' do
      mock_manager = object_double('Mock Password Manager', {
        :remove_password => nil,
        :location        => "'production' Environment"
      })

      expected_output = <<~EOM
        Processing 'name1' in 'production' Environment... done.
          Removed 'name1'

        Processing 'name2' in 'production' Environment... done.
          Removed 'name2'

        Processing 'name3' in 'production' Environment... done.
          Removed 'name3'

        Processing 'name4' in 'production' Environment... done.
          Removed 'name4'

      EOM

      @remover.remove_passwords(mock_manager, names, true)
      expect( @output.string ).to eq(expected_output)
    end

    it 'removes as many passwords as possible and fails with list of ' +
       'password remove failures' do

      mock_manager = object_double('Mock Password Manager', {
        :remove_password => nil,
        :location        => "'production' Environment"
      })

      allow(mock_manager).to receive(:remove_password).with('name1')
        .and_return(nil)

      allow(mock_manager).to receive(:remove_password).with('name4')
        .and_return(nil)

      allow(mock_manager).to receive(:remove_password).with('name2').and_raise(
        Simp::Cli::ProcessingError, 'Remove failed: password not found')

      allow(mock_manager).to receive(:remove_password).with('name3').and_raise(
        Simp::Cli::ProcessingError, 'Remove failed: permission denied')


      expected_stdout = <<~EOM
        Processing 'name1' in 'production' Environment... done.
          Removed 'name1'

        Processing 'name2' in 'production' Environment... done.
          Skipped 'name2'

        Processing 'name3' in 'production' Environment... done.
          Skipped 'name3'

        Processing 'name4' in 'production' Environment... done.
          Removed 'name4'

      EOM

      expected_err_msg = <<~EOM
        Failed to remove 2 out of 4 passwords in 'production' Environment:
          'name2': Remove failed: password not found
          'name3': Remove failed: permission denied
      EOM

      expect { @remover.remove_passwords(mock_manager, names, true) }
        .to raise_error( Simp::Cli::ProcessingError,
        expected_err_msg.strip)

      expect( @output.string ).to eq(expected_stdout)
    end
  end

  #
  # Simp::Cli::Commands::Command API methods
  #
  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Passgen::Remove.description}/
      expect{ @remover.help }.to output(expected_stdout_regex).to_stdout
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
        expect { @remover.run(['name1', '-e', 'oops']) }.to raise_error(
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
          .with(@module_list_command_prod, false, @remover.logger)
          .and_return(module_list_results)

        expect { @remover.run(['name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Invalid Puppet environment 'production': " +
          'simp-simplib is not installed')
      end

      it 'fails when LegacyPasswordManager cannot be constructed' do
        allow(@remover).to receive(:get_simplib_version).and_return('3.0.0')
        password_env_dir = File.join(@var_dir, 'simp', 'environments')
        default_password_dir = File.join(password_env_dir, 'production',
          'simp_autofiles', 'gen_passwd')

        FileUtils.mkdir_p(File.dirname(default_password_dir))
        FileUtils.touch(default_password_dir)
        expect { @remover.run(['name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{default_password_dir}' is not a directory")
      end
    end

    # This test verifies that the correct password manager object has been
    # instantiated and used with appropriate options from the command line
    # in Simp::Cli::Commands::Passgen::Remove#remove_passwords.
    describe 'using password manager' do
      context 'legacy manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @remover.logger)
            .and_return(@old_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @remover.logger)
            .and_return(@old_simplib_module_list_results)
        end

        it 'removes names for default env when prompt returns yes' do
          allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)

          mock_manager = object_double('Mock LegacyPasswordManager', {
            :remove_password => nil,
            :location        => "'production' Environment"
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(mock_manager).to receive(:remove_password).with('name2')
            .and_return(nil)

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', nil).and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Processing 'name1' in 'production' Environment... done.
              Removed 'name1'

            Processing 'name2' in 'production' Environment... done.
              Removed 'name2'

          EOM

          @remover.run(['name1,name2'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'removes names for default environment without prompting when ' +
           '--force' do

          mock_manager = object_double('Mock LegacyPasswordManager', {
            :remove_password => nil,
            :location        => "'production' Environment"
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', nil).and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Processing 'name1' in 'production' Environment...
              Removed 'name1'

          EOM

          @remover.run(['name1', '--force'])
        end

        it 'removes names for specified env' do
          allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)

          mock_manager = object_double('Mock LegacyPasswordManager', {
            :remove_password => nil,
            :location        => "'dev' Environment"
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('dev', nil).and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'dev'... done.
            Processing 'name1' in 'dev' Environment... done.
              Removed 'name1'

          EOM

          @remover.run(['name1', '-e', 'dev'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'removes names for specified directory' do
          allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)

          mock_manager = object_double('Mock LegacyPasswordManager', {
            :remove_password => nil,
            :location  => '/some/passgen/path'
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', '/some/passgen/path').and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Processing 'name1' in /some/passgen/path... done.
              Removed 'name1'

          EOM

          @remover.run(['name1', '-d', '/some/passgen/path'])
          expect( @output.string ).to eq(expected_output)
        end
      end

      context 'current manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @remover.logger)
            .and_return(@new_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @remover.logger)
            .and_return(@new_simplib_module_list_results)
        end

        it 'removes names for default env when prompt returns yes' do
          allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)

          mock_manager = object_double('Mock PasswordManager', {
            :remove_password => nil,
            :location        => "'production' Environment"
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(mock_manager).to receive(:remove_password).with('name2')
            .and_return(nil)

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('production', nil, nil).and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Processing 'name1' in 'production' Environment... done.
              Removed 'name1'

            Processing 'name2' in 'production' Environment... done.
              Removed 'name2'

          EOM

          @remover.run(['name1,name2'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'removes names for default env without prompting when ' +
           '--force' do

          mock_manager = object_double('Mock PasswordManager', {
            :remove_password => nil,
            :location        => "'production' Environment"
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('production', nil, nil).and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Processing 'name1' in 'production' Environment... done.
              Removed 'name1'

          EOM

          @remover.run(['name1', '--force'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'removes passwords for specified names in specified <env,backend>' do
          allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)

          mock_manager = object_double('Mock PasswordManager', {
            :remove_password => nil,
            :location        =>
              "'dev' Environment, 'backend3' simpkv Backend"
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('dev', 'backend3', nil).and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'dev'... done.
            Processing 'name1' in 'dev' Environment, 'backend3' simpkv Backend... done.
              Removed 'name1'

          EOM

          @remover.run(['name1', '-e', 'dev', '--backend', 'backend3'])

          expect( @output.string ).to eq(expected_output)
        end
      end
    end

    describe 'option validation' do
      it 'requires non-empty name list' do
        expect { @remover.run([]) }.to raise_error(
          Simp::Cli::ProcessingError,
          'Password names are missing from command line')
      end
    end
  end
end
