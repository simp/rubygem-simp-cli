require 'simp/cli/commands/passgen'
require 'simp/cli/passgen/legacy_password_manager'
require 'simp/cli/passgen/password_manager'

require 'etc'
require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Commands::Passgen do
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
    @passgen = Simp::Cli::Commands::Passgen.new

    # make sure notice and above messages are output
    @passgen.set_up_global_logger
  end

  after :each do
    @input.close
    @output.close
    $terminal = @prev_terminal
    FileUtils.remove_entry_secure @tmp_dir, true
  end

  let(:module_list_old_simplib) {
    <<-EOM
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
    <<-EOM
Warning: Missing dependency 'puppetlabs-apt':
  'puppetlabs-postgresql' (v5.12.1) requires 'puppetlabs-apt' (>= 2.0.0 < 7.0.0)
    EOM
  }

  #
  # Custom Method Tests
  #
  describe '#find_valid_environments' do

    it 'returns empty hash when Puppet environments dir is missing/inaccessible' do
      expect( @passgen.find_valid_environments ).to eq({})
    end

    it 'returns empty hash when Puppet environments dir is empty' do
      FileUtils.mkdir_p(@puppet_env_dir)
      expect( @passgen.find_valid_environments ).to eq({})
    end

    it 'returns empty hash when no Puppet envs have simp-simplib installed' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'dev'))
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'test'))

      module_list_results = {
        :status => true,
        :stdout => module_list_no_simplib,
        :stderr => missing_deps_warnings
      }

      [
        'puppet module list --color=false --environment=production',
        'puppet module list --color=false --environment=dev',
        'puppet module list --color=false --environment=test'
      ].each do |command|
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(command, false, @passgen.logger).and_return(module_list_results)
      end

      expect( @passgen.find_valid_environments ).to eq({})
    end

    it 'returns hash with only Puppet envs that have simp-simplib installed' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      command = 'puppet module list --color=false --environment=production'
      module_list_results = {
        :status => true,
        :stdout => module_list_old_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @passgen.logger).and_return(module_list_results)

      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'dev'))
      command = 'puppet module list --color=false --environment=dev'
      module_list_results = {
        :status => true,
        :stdout => module_list_no_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @passgen.logger).and_return(module_list_results)

      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'test'))
      command = 'puppet module list --color=false --environment=test'
      module_list_results = {
        :status => true,
        :stdout => module_list_new_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @passgen.logger).and_return(module_list_results)

      expected = { 'production' => '3.15.3', 'test' => '4.0.0' }
      expect( @passgen.find_valid_environments ).to eq(expected)
    end

    it 'fails if puppet module list command fails' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      command = 'puppet module list --color=false --environment=production'
      module_list_results = {
        :status => false,
        :stdout => '',
        :stderr => 'some failure message'
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @passgen.logger).and_return(module_list_results)

      expect{ @passgen.find_valid_environments }.to raise_error(
        Simp::Cli::ProcessingError,
        "Unable to determine simplib version in 'production' environment")
    end
  end

  describe '#legacy_passgen?' do
    it 'should return true for old simplib' do
      expect( @passgen.legacy_passgen?('3.17.0') ).to eq(true)
    end

    it 'should return false for new simplib' do
      expect( @passgen.legacy_passgen?('4.0.1') ).to eq(false)
    end
  end

  describe '#remove_passwords' do
    before :each do
    end

    let(:names) { [ 'name1', 'name2', 'name3', 'name4' ] }

    it 'removes passwords when force_remove=false & prompt returns yes' do
      allow(Simp::Cli::Passgen::Utils).to receive(:yes_or_no).and_return(true)

      # mock the password manager with a double of String in which methods
      # needed have been defined
      mock_manager = object_double('Mock Password Manager', {
        :remove_password => nil,
        :location        => "'production' Environment"
      })

      expected_output = <<-EOM
Processing 'name1' in 'production' Environment... done.
  Removed 'name1'

Processing 'name2' in 'production' Environment... done.
  Removed 'name2'

Processing 'name3' in 'production' Environment... done.
  Removed 'name3'

Processing 'name4' in 'production' Environment... done.
  Removed 'name4'

      EOM

      @passgen.remove_passwords(mock_manager, names, false)
      expect( @output.string ).to eq(expected_output)
    end

    it 'does not remove passwords when force_remove=false & prompt returns no' do
      allow(Simp::Cli::Passgen::Utils).to receive(:yes_or_no).and_return(false)
      mock_manager = object_double('Mock Password Manager', {
        :remove_password => nil,
        :location        => "'production' Environment"
      })
      expected_output = <<-EOM
Skipped 'name1' in 'production' Environment

Skipped 'name2' in 'production' Environment

Skipped 'name3' in 'production' Environment

Skipped 'name4' in 'production' Environment

      EOM

      @passgen.remove_passwords(mock_manager, names, false)
      expect( @output.string ).to eq(expected_output)
    end

    it 'removes password names when force_remove=true' do
      mock_manager = object_double('Mock Password Manager', {
        :remove_password => nil,
        :location        => "'production' Environment"
      })

      expected_output = <<-EOM
Processing 'name1' in 'production' Environment... done.
  Removed 'name1'

Processing 'name2' in 'production' Environment... done.
  Removed 'name2'

Processing 'name3' in 'production' Environment... done.
  Removed 'name3'

Processing 'name4' in 'production' Environment... done.
  Removed 'name4'

      EOM

      @passgen.remove_passwords(mock_manager, names, true)
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


      expected_stdout = <<-EOM
Processing 'name1' in 'production' Environment... done.
  Removed 'name1'

Processing 'name2' in 'production' Environment... done.
  Skipped 'name2'

Processing 'name3' in 'production' Environment... done.
  Skipped 'name3'

Processing 'name4' in 'production' Environment... done.
  Removed 'name4'

      EOM

      expected_err_msg = <<-EOM
Failed to remove the following passwords in 'production' Environment:
  'name2': Remove failed: password not found
  'name3': Remove failed: permission denied
      EOM

      expect { @passgen.remove_passwords(mock_manager, names, true) }
        .to raise_error( Simp::Cli::ProcessingError,
        expected_err_msg.strip)

      expect( @output.string ).to eq(expected_stdout)
    end
  end

  describe '#set_passwords' do
    let(:names) { [ 'name1', 'name2', 'name3', 'name4' ] }
    let(:password_gen_options) { { :auto_gen => true } }

    it 'sets passwords to values generated by the password manager' do
      mock_manager = object_double('Mock Password Manager', {
        :set_password => nil,
        :location     => "'production' Environment"
      })

      names.each do |name|
        allow(mock_manager).to receive(:set_password).
          with(name, password_gen_options).and_return("#{name}_new_password")
      end

      expected_output = <<-EOM
Processing 'name1' in 'production' Environment... done.
  'name1' new password: name1_new_password

Processing 'name2' in 'production' Environment... done.
  'name2' new password: name2_new_password

Processing 'name3' in 'production' Environment... done.
  'name3' new password: name3_new_password

Processing 'name4' in 'production' Environment... done.
  'name4' new password: name4_new_password

      EOM

      @passgen.set_passwords(mock_manager, names, password_gen_options)
      expect( @output.string ).to eq(expected_output)
    end

    it 'gathers passwords from the user and then sets them' do
      passwords = []
      names.each do |name|
        passwords << "#{name}_new_password"
      end

      allow(Simp::Cli::Passgen::Utils).to receive(:get_password).with(5, false)
        .and_return(*passwords)

      mock_manager = object_double('Mock Password Manager', {
        :set_password => nil,
        :location     => "'production' Environment"
      })

      password_options = { :auto_gen => false, :validate => false }
      names.each do |name|
        options = { :password => "#{name}_new_password" }
        options.merge!(password_options)
        allow(mock_manager).to receive(:set_password).
          with(name, options).and_return(options[:password])
      end

      expected_output = <<-EOM
Processing 'name1' in 'production' Environment... done.
  'name1' new password: name1_new_password

Processing 'name2' in 'production' Environment... done.
  'name2' new password: name2_new_password

Processing 'name3' in 'production' Environment... done.
  'name3' new password: name3_new_password

Processing 'name4' in 'production' Environment... done.
  'name4' new password: name4_new_password

      EOM

      @passgen.set_passwords(mock_manager, names, password_options)
      expect( @output.string ).to eq(expected_output)
    end

    it 'sets as many passwords as possible and fails with list of password ' +
       'set failures' do

      mock_manager = object_double('Mock Password Manager', {
        :set_password => 'new_password',
        :location     => "'production' Environment"
      })
      allow(mock_manager).to receive(:set_password).
        with('name1', password_gen_options).and_return('name1_new_password')
      allow(mock_manager).to receive(:set_password).
        with('name4', password_gen_options).and_return('name4_new_password')
      allow(mock_manager).to receive(:set_password).
        with('name2', password_gen_options).
        and_raise(Simp::Cli::ProcessingError, 'Set failed: permission denied')

      allow(mock_manager).to receive(:set_password).
        with('name3', password_gen_options).
        and_raise(Simp::Cli::ProcessingError,
       'Set failed: connection timed out')

      expected_stdout = <<-EOM
Processing 'name1' in 'production' Environment... done.
  'name1' new password: name1_new_password

Processing 'name2' in 'production' Environment... done.
  Skipped 'name2'

Processing 'name3' in 'production' Environment... done.
  Skipped 'name3'

Processing 'name4' in 'production' Environment... done.
  'name4' new password: name4_new_password

      EOM

      expected_err_msg = <<-EOM
Failed to set 2 out of 4 passwords in 'production' Environment:
  'name2': Set failed: permission denied
  'name3': Set failed: connection timed out
      EOM

      expect { @passgen.set_passwords(mock_manager, names, password_gen_options) }
        .to raise_error(
        Simp::Cli::ProcessingError,
        expected_err_msg.strip)
      expect( @output.string ).to eq(expected_stdout)
    end
  end

  describe '#show_environment_list' do
    it 'lists no environments, when no environments exist' do
      expected_output =<<-EOM
Looking for environments with simp-simplib installed... done.

No environments with simp-simplib installed were found.

      EOM
      @passgen.show_environment_list
      expect( @output.string ).to eq(expected_output)
    end

    it 'lists no environments, when no environments with simp-simplib exist' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      command = 'puppet module list --color=false --environment=production'
      module_list_results = {
        :status => true,
        :stdout => module_list_no_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @passgen.logger).and_return(module_list_results)

      @passgen.show_environment_list
      expected_output =<<-EOM
Looking for environments with simp-simplib installed... done.

No environments with simp-simplib installed were found.

      EOM
      expect( @output.string ).to eq(expected_output)
    end

    it 'lists available environments with simp-simplib installed' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      command = 'puppet module list --color=false --environment=production'
      module_list_results = {
        :status => true,
        :stdout => module_list_old_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @passgen.logger).and_return(module_list_results)

      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'dev'))
      command = 'puppet module list --color=false --environment=dev'
      module_list_results = {
        :status => true,
        :stdout => module_list_no_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @passgen.logger).and_return(module_list_results)

      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'test'))
      command = 'puppet module list --color=false --environment=test'
      module_list_results = {
        :status => true,
        :stdout => module_list_new_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @passgen.logger).and_return(module_list_results)

      expected_output = <<-EOM
Looking for environments with simp-simplib installed... done.

Environments
============
production
test

      EOM

      @passgen.show_environment_list
      expect( @output.string ).to eq(expected_output)
    end

    it 'fails if puppet module list command fails' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      command = 'puppet module list --color=false --environment=production'
      module_list_results = {
        :status => false,
        :stdout => '',
        :stderr => 'some failure message'
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @passgen.logger).and_return(module_list_results)

      expect { @passgen.show_environment_list }.to raise_error(
        Simp::Cli::ProcessingError,
        "Unable to determine simplib version in 'production' environment")
    end
  end

  describe '#show_name_list' do
    it 'reports no password names when list is empty' do
      mock_manager = object_double('Mock Password Manager', {
        :name_list => [],
        :location  => "'production' Environment"
      })

      expected_output =<<-EOM
Retrieving password names... done.

No passwords found in 'production' Environment

      EOM

      @passgen.show_name_list(mock_manager)
      expect( @output.string ).to eq(expected_output)
    end

    it 'lists available password names' do
      mock_manager = object_double('Mock Password Manager', {
        :name_list => [ 'name1', 'name2', 'name3'],
        :location  => "'production' Environment"
      })

      expected_output = <<-EOM
Retrieving password names... done.

'production' Environment Password Names
=======================================
name1
name2
name3

      EOM

      @passgen.show_name_list(mock_manager)
      expect( @output.string ).to eq(expected_output)
    end

    it 'fails when password list operation fails' do
      mock_manager = object_double('Mock Password Manager', {
        :name_list => nil,
        :location  => "'production' Environment"
      })

      allow(mock_manager).to receive(:name_list).and_raise(
        Simp::Cli::ProcessingError, 'List failed: connection timed out')

      expect { @passgen.show_name_list(mock_manager) }.to raise_error(
        Simp::Cli::ProcessingError,
        "List for 'production' Environment failed: " +
        'List failed: connection timed out')
    end
  end

  describe '#show_passwords' do
    let(:names) { [ 'name1', 'name2', 'name3', 'name4' ] }

    it 'lists password names' do
      mock_manager = object_double('Mock Password Manager', {
        :password_info => nil,
        :location      => "'production' Environment"
      })

      [ 'name1', 'name2', 'name4'].each do |name|
        allow(mock_manager).to receive(:password_info).with(name).and_return(
          {
            'value' => {
               'password' => "#{name}_password", 'salt' => "#{name}_salt"
            },
            'metadata' => { 'history' =>
              [ [ "#{name}_password_last", "#{name}_salt_last"] ]
            }
          }
        )
      end

      allow(mock_manager).to receive(:password_info).with('name3').and_return(
        {
          'value' => { 'password' => 'name3_password', 'salt' => 'name3_salt' },
          'metadata' => { 'history' => [] }
        }
      )

      expected_output = <<-EOM
Retrieving password information... done.

'production' Environment Passwords
==================================
Name: name1
  Current:  name1_password
  Previous: name1_password_last

Name: name2
  Current:  name2_password
  Previous: name2_password_last

Name: name3
  Current:  name3_password

Name: name4
  Current:  name4_password
  Previous: name4_password_last

      EOM

      @passgen.show_passwords(mock_manager, names)
      expect( @output.string ).to eq(expected_output)
    end

    it 'lists info for as many passwords as possible and fails with list ' +
       'of retrieval failures' do

      mock_manager = object_double('Mock Password Manager', {
        :password_info => nil,
        :location      => "'production' Environment"
      })

      [ 'name1', 'name4'].each do |name|
        allow(mock_manager).to receive(:password_info).with(name).and_return(
          {
            'value' => {
              'password' => "#{name}_password", 'salt' => "#{name}_salt"
            },
            'metadata' => { 'history' =>
              [ [ "#{name}_password_last", "#{name}_salt_last"] ]
            }
          }
        )
      end

      allow(mock_manager).to receive(:password_info).with('name2').
        and_raise(Simp::Cli::ProcessingError, 'Set failed: permission denied')

      allow(mock_manager).to receive(:password_info).with('name3').
        and_raise(Simp::Cli::ProcessingError,
       'Set failed: connection timed out')

      expected_stdout = <<-EOM
Retrieving password information... done.

'production' Environment Passwords
==================================
Name: name1
  Current:  name1_password
  Previous: name1_password_last

Name: name2
  Skipped

Name: name3
  Skipped

Name: name4
  Current:  name4_password
  Previous: name4_password_last

      EOM

      expected_err_msg = <<-EOM
Failed to retrieve 2 out of 4 passwords in 'production' Environment:
  'name2': Set failed: permission denied
  'name3': Set failed: connection timed out
      EOM

      expect { @passgen.show_passwords(mock_manager, names) }.to raise_error(
        Simp::Cli::ProcessingError, expected_err_msg.strip)

      expect( @output.string ).to eq(expected_stdout)
    end
  end

  #
  # Simp::Cli::Commands::Command API methods
  #
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

    # This test verifies Simp::Cli::Commands::Passgen#show_environment_list
    # is called.
    describe '--list-env option' do
      it 'lists available environments with simp-simplib installed' do
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(@module_list_command_prod, false, @passgen.logger)
          .and_return(@old_simplib_module_list_results)

        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(@module_list_command_dev, false, @passgen.logger)
          .and_return(@new_simplib_module_list_results)

        expected_output = <<-EOM
Looking for environments with simp-simplib installed... done.

Environments
============
dev
production

        EOM

        @passgen.run(['-E'])
        expect( @output.string ).to eq(expected_output)
      end
    end

    describe 'setup error cases for options using a password manager' do
      it 'fails when the environment does not exist' do
        expect { @passgen.run(['-l', '-e', 'oops']) }.to raise_error(
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
          .with(@module_list_command_prod, false, @passgen.logger)
          .and_return(module_list_results)

        expect { @passgen.run(['-l']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Invalid Puppet environment 'production': " +
          'simp-simplib is not installed')
      end

      it 'fails when LegacyPasswordManager cannot be constructed' do
        allow(@passgen).to receive(:get_simplib_version).and_return('3.0.0')
        password_env_dir = File.join(@var_dir, 'simp', 'environments')
        default_password_dir = File.join(password_env_dir, 'production',
          'simp_autofiles', 'gen_passwd')

        FileUtils.mkdir_p(File.dirname(default_password_dir))
        FileUtils.touch(default_password_dir)
        expect { @passgen.run(['-l']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{default_password_dir}' is not a directory")
      end
    end

    # This test verifies that the correct password manager object has been
    # instantiated and used in Simp::Cli::Commands::Passgen#show_name_list.
    describe '--list-names option' do
      context 'legacy manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @passgen.logger)
            .and_return(@old_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @passgen.logger)
            .and_return(@old_simplib_module_list_results)
        end

        it 'lists available names for default environment' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :name_list => [ 'name1', 'name2' ],
            :location  => "'production' Environment"
          })

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', nil).and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'production'... done.
Retrieving password names... done.

'production' Environment Password Names
=======================================
name1
name2

          EOM

          @passgen.run(['-l'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists available names for specified environment' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :name_list => [ 'name1' ],
            :location  => "'dev' Environment"
          })

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('dev', nil).and_return(mock_manager)
          expected_output = <<-EOM
Initializing for environment 'dev'... done.
Retrieving password names... done.

'dev' Environment Password Names
================================
name1

          EOM

          @passgen.run(['-l', '-e', 'dev'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists available names for specified directory' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :name_list => [ 'name1' ],
            :location  => '/some/passgen/path'
          })

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', '/some/passgen/path').and_return(mock_manager)
          expected_output = <<-EOM
Initializing for environment 'production'... done.
Retrieving password names... done.

/some/passgen/path Password Names
=================================
name1

          EOM

          @passgen.run(['-l', '-d', '/some/passgen/path'])
          expect( @output.string ).to eq(expected_output)
        end

      end

      context 'current manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @passgen.logger)
            .and_return(@new_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @passgen.logger)
            .and_return(@new_simplib_module_list_results)
        end

        it 'lists available names for the top folder of the default env' do
          mock_manager = object_double('Mock PasswordManager', {
            :name_list => [ 'name1', 'name2' ],
            :location  => "'production' Environment"
          })

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('production', nil, nil).and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'production'... done.
Retrieving password names... done.

'production' Environment Password Names
=======================================
name1
name2

          EOM

          @passgen.run(['-l'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists available names for the specified <env,folder,backend>' do
          mock_manager = object_double('Mock PasswordManager', {
            :name_list => [ 'name1' ],
            :location  =>
              "'dev' Environment, 'folder1' Folder, 'backend3' libkv Backend"
          })

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('dev', 'backend3', 'folder1').and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'dev'... done.
Retrieving password names... done.

'dev' Environment, 'folder1' Folder, 'backend3' libkv Backend Password Names
============================================================================
name1

          EOM

          @passgen.run(['-l', '-e', 'dev', '--folder', 'folder1',
            '--backend', 'backend3'])

          expect( @output.string ).to eq(expected_output)
        end
      end
    end

    # This test verifies that the correct password manager object has been
    # instantiated and used in Simp::Cli::Commands::Passgen#show_passwords.
    describe '--name option' do
      let(:names) { [ 'name1', 'name2' ] }
      let(:password_info1) { {
        'value'    => { 'password' => 'password1', 'salt' => 'salt1'},
        'metadata' => {
          'complex'      => 1,
          'complex_only' => false,
          'history'      => [
            ['password1_old', 'salt1_old'],
            ['password1_old_old', 'salt1_old_old']
          ]
        }
      } }

      let(:password_info2) { {
        'value' => { 'password' => 'password2', 'salt' => 'salt2'},
        'metadata' => {
          'complex'      => 1,
          'complex_only' => false,
          'history'      => []
        }
      } }

      context 'legacy manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @passgen.logger)
            .and_return(@old_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @passgen.logger)
            .and_return(@old_simplib_module_list_results)
        end

        it 'lists passwords for specified names in default env' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :password_info => nil,
            :location      => "'production' Environment"
          })

          allow(mock_manager).to receive(:password_info).with('name1')
            .and_return(password_info1)

          allow(mock_manager).to receive(:password_info).with('name2')
            .and_return(password_info2)

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', nil).and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'production'... done.
Retrieving password information... done.

'production' Environment Passwords
==================================
Name: name1
  Current:  password1
  Previous: password1_old

Name: name2
  Current:  password2

          EOM

          @passgen.run(['-n', 'name1,name2'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists passwords for specified names in specified env' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :password_info => nil,
            :location      => "'dev' Environment"
          })

          allow(mock_manager).to receive(:password_info).with('name1')
            .and_return(password_info1)

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('dev', nil).and_return(mock_manager)
          expected_output = <<-EOM
Initializing for environment 'dev'... done.
Retrieving password information... done.

'dev' Environment Passwords
===========================
Name: name1
  Current:  password1
  Previous: password1_old

          EOM

          @passgen.run(['-n', 'name1', '-e', 'dev'])
          expect( @output.string ).to eq(expected_output)
        end
      end

      context 'current manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @passgen.logger)
            .and_return(@new_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @passgen.logger)
            .and_return(@new_simplib_module_list_results)
        end

        it 'lists passwords for specified names in default env' do
          mock_manager = object_double('Mock PasswordManager', {
            :password_info => nil,
            :location      => "'production' Environment"
          })

          allow(mock_manager).to receive(:password_info).with('name1')
            .and_return(password_info1)

          allow(mock_manager).to receive(:password_info).with('name2')
            .and_return(password_info2)

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('production', nil, nil).and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'production'... done.
Retrieving password information... done.

'production' Environment Passwords
==================================
Name: name1
  Current:  password1
  Previous: password1_old

Name: name2
  Current:  password2

          EOM

          @passgen.run(['-n', 'name1,name2'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists passwords for specified names in specified ' +
           '<env,folder,backend>' do

          mock_manager = object_double('Mock PasswordManager', {
            :password_info => nil,
            :location      =>
              "'dev' Environment, 'folder1' Folder, 'backend3' libkv Backend"
          })

          allow(mock_manager).to receive(:password_info).with('name1')
            .and_return(password_info1)

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('dev', 'backend3', 'folder1').and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'dev'... done.
Retrieving password information... done.

'dev' Environment, 'folder1' Folder, 'backend3' libkv Backend Passwords
=======================================================================
Name: name1
  Current:  password1
  Previous: password1_old

          EOM

          @passgen.run(['-n', 'name1', '-e', 'dev', '--folder', 'folder1',
            '--backend', 'backend3'])

          expect( @output.string ).to eq(expected_output)
        end
      end
    end

    # This test verifies that the correct password manager object has been
    # instantiated and used with appropriate options from the command line
    # in Simp::Cli::Commands::Passgen#remove_passwords.
    describe '--remove option' do
      context 'legacy manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @passgen.logger)
            .and_return(@old_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @passgen.logger)
            .and_return(@old_simplib_module_list_results)
        end

        it 'removes names for default env when prompt returns yes' do
          allow(Simp::Cli::Passgen::Utils).to receive(:yes_or_no)
            .and_return(true)

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

          expected_output = <<-EOM
Initializing for environment 'production'... done.
Processing 'name1' in 'production' Environment... done.
  Removed 'name1'

Processing 'name2' in 'production' Environment... done.
  Removed 'name2'

          EOM

          @passgen.run(['-r', 'name1,name2'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'removes names for default environment without prompting when ' +
           '--force-remove' do

          mock_manager = object_double('Mock LegacyPasswordManager', {
            :remove_password => nil,
            :location        => "'production' Environment"
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', nil).and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'production'... done.
Processing 'name1' in 'production' Environment...
  Removed 'name1'

          EOM

          args = ['-r', 'name1', '--force-remove']
          @passgen.run(args)
        end

        it 'removes names for specified env' do
          allow(Simp::Cli::Passgen::Utils).to receive(:yes_or_no)
            .and_return(true)

          mock_manager = object_double('Mock LegacyPasswordManager', {
            :remove_password => nil,
            :location        => "'dev' Environment"
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('dev', nil).and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'dev'... done.
Processing 'name1' in 'dev' Environment... done.
  Removed 'name1'

          EOM

          @passgen.run(['-r', 'name1', '-e', 'dev'])
          expect( @output.string ).to eq(expected_output)
        end
      end

      context 'current manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @passgen.logger)
            .and_return(@new_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @passgen.logger)
            .and_return(@new_simplib_module_list_results)
        end

        it 'removes names for default env when prompt returns yes' do
          allow(Simp::Cli::Passgen::Utils).to receive(:yes_or_no)
            .and_return(true)

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

          expected_output = <<-EOM
Initializing for environment 'production'... done.
Processing 'name1' in 'production' Environment... done.
  Removed 'name1'

Processing 'name2' in 'production' Environment... done.
  Removed 'name2'

          EOM

          @passgen.run(['-r', 'name1,name2'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'removes names for default env without prompting when ' +
           '--force-remove' do

          mock_manager = object_double('Mock PasswordManager', {
            :remove_password => nil,
            :location        => "'production' Environment"
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('production', nil, nil).and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'production'... done.
Processing 'name1' in 'production' Environment... done.
  Removed 'name1'

          EOM

          @passgen.run(['-r', 'name1', '--force-remove'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'removes passwords for specified names in specified ' +
           '<env,folder,backend>' do

          allow(Simp::Cli::Passgen::Utils).to receive(:yes_or_no)
            .and_return(true)

          mock_manager = object_double('Mock PasswordManager', {
            :remove_password => nil,
            :location        => 
              "'dev' Environment, 'folder1' Folder, 'backend3' libkv Backend"
          })

          allow(mock_manager).to receive(:remove_password).with('name1')
            .and_return(nil)

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('dev', 'backend3', 'folder1').and_return(mock_manager)

expected_output = <<-EOM
Initializing for environment 'dev'... done.
Processing 'name1' in 'dev' Environment, 'folder1' Folder, 'backend3' libkv Backend... done.
  Removed 'name1'

          EOM

          @passgen.run(['-r', 'name1', '-e', 'dev', '--folder', 'folder1',
            '--backend', 'backend3'])

          expect( @output.string ).to eq(expected_output)
        end
      end
    end

    # This test verifies that the correct password manager object has been
    # instantiated and used with appropriate options from the command line
    # in Simp::Cli::Commands::Passgen#set_passwords.
    describe '--set option' do
      let(:default_options) {
        {
          :auto_gen             => false,
          :validate             => false,
          :length               => nil,
          :default_length       => 32,
          :minimum_length       => 8,
          :complexity           => nil,
          :default_complexity   => 0,
          :complex_only         => nil,
          :default_complex_only => false
         }
      }

      let(:custom_args) { [
        '-e', 'dev',
        '--auto-gen',
        '--validate',
        '--length', '48',
        '--complexity', '2',
        '--complex_only'
      ] }

      let(:custom_options) {
        options = default_options.dup

        # :auto_gen and :validate enabled via command line options
        options[:auto_gen]     = true
        options[:validate]     = true

        # nil options set via command line options
        options[:length]       = 48
        options[:complexity]   = 2
        options[:complex_only] = true

        options
      }

      context 'legacy manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @passgen.logger)
            .and_return(@old_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @passgen.logger)
            .and_return(@old_simplib_module_list_results)
        end

        it 'sets passwords for names in default env using default options' do
          allow(Simp::Cli::Passgen::Utils).to receive(:get_password).with(5, false)
            .and_return('name1_new_password', 'name2_new_password')

          mock_manager = object_double('Mock LegacyPasswordManager', {
            :set_password => nil,
            :location     => "'production' Environment"
          })

          options = { :password => 'name1_new_password' }
          options.merge!(default_options)
          allow(mock_manager).to receive(:set_password)
            .with('name1', options).and_return('name1_new_password')

          options = { :password => 'name2_new_password' }
          options.merge!(default_options)
          allow(mock_manager).to receive(:set_password)
            .with('name2', options).and_return('name2_new_password')

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', nil).and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'production'... done.
Processing 'name1' in 'production' Environment... done.
  'name1' new password: name1_new_password

Processing 'name2' in 'production' Environment... done.
  'name2' new password: name2_new_password

          EOM

          @passgen.run(['-s', 'name1,name2'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'sets passwords for names in specified env using custom options' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :set_password => nil,
            :location     => "'dev' Environment"
          })

          allow(mock_manager).to receive(:set_password)
            .with('name1', custom_options).and_return('name1_new_password')

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('dev', nil).and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'dev'... done.
Processing 'name1' in 'dev' Environment... done.
  'name1' new password: name1_new_password

          EOM

          @passgen.run(['-s', 'name1'] + custom_args)
          expect( @output.string ).to eq(expected_output)
        end
      end

      context 'current manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @passgen.logger)
            .and_return(@new_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @passgen.logger)
            .and_return(@new_simplib_module_list_results)
        end

        it 'sets passwords for names in default env using default options' do
          allow(Simp::Cli::Passgen::Utils).to receive(:get_password).with(5, false)
            .and_return('name1_new_password', 'name2_new_password')

          mock_manager = object_double('Mock PasswordManager', {
            :set_password => nil,
            :location     => "'production' Environment"
          })

          options = { :password => 'name1_new_password' }
          options.merge!(default_options)
          allow(mock_manager).to receive(:set_password)
            .with('name1', options).and_return('name1_new_password')

          options = { :password => 'name2_new_password' }
          options.merge!(default_options)
          allow(mock_manager).to receive(:set_password)
            .with('name2', options).and_return('name2_new_password')

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('production', nil, nil).and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'production'... done.
Processing 'name1' in 'production' Environment... done.
  'name1' new password: name1_new_password

Processing 'name2' in 'production' Environment... done.
  'name2' new password: name2_new_password

          EOM

          @passgen.run(['-s', 'name1,name2'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'sets passwords for names in specified env using custom options' do
          mock_manager = object_double('Mock PasswordManager', {
            :set_password => nil,
            :location     =>
              "'dev' Environment, 'folder1' Folder, 'backend3' libkv Backend"
          })

          allow(mock_manager).to receive(:set_password)
            .with('name1', custom_options).and_return('name1_new_password')

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('dev', 'backend3', 'folder1').and_return(mock_manager)

          expected_output = <<-EOM
Initializing for environment 'dev'... done.
Processing 'name1' in 'dev' Environment, 'folder1' Folder, 'backend3' libkv Backend... done.
  'name1' new password: name1_new_password

          EOM

          @passgen.run(['-s', 'name1', '--folder', 'folder1',
            '--backend', 'backend3'] + custom_args)
          expect( @output.string ).to eq(expected_output)
        end
      end
    end

    describe 'option validation' do
      it 'requires operation option to be specified' do
        expect { @passgen.run([]) }.to raise_error(OptionParser::ParseError,
          /The SIMP Passgen Tool requires at least one option/)

        expect { @passgen.run(['-e', 'production']) }
          .to raise_error(OptionParser::ParseError,
          /No password operation specified/)
      end

      {
        'remove' => '--remove',
        'set'    => '--set',
        'show'   => '--name'
      }.each do |type, option|
        it "requires #{option} option to have non-empty name list" do
          expect { @passgen.run([option, ","]) }.to raise_error(
            OptionParser::ParseError,
            /Only empty names specified for #{type} passwords operation/)
        end
      end
    end
  end
end
