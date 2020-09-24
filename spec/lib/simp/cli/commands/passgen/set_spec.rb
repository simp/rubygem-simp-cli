require 'simp/cli/commands/passgen'
require 'simp/cli/commands/passgen/set'
require 'simp/cli/passgen/legacy_password_manager'
require 'simp/cli/passgen/password_manager'

require 'etc'
require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Commands::Passgen::Set do
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
    HighLine.default_instance = HighLine.new(@input, @output)

    allow(Simp::Cli::Utils).to receive(:puppet_info).and_return(puppet_info)
    @setter = Simp::Cli::Commands::Passgen::Set.new

    # make sure notice and above messages are output
    @setter.set_up_global_logger
  end

  after :each do
    @input.close
    @output.close
    HighLine.default_instance = HighLine.new
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

      expected_output = <<~EOM
        Processing 'name1' in 'production' Environment... done.
          'name1' new password: name1_new_password

        Processing 'name2' in 'production' Environment... done.
          'name2' new password: name2_new_password

        Processing 'name3' in 'production' Environment... done.
          'name3' new password: name3_new_password

        Processing 'name4' in 'production' Environment... done.
          'name4' new password: name4_new_password

      EOM

      @setter.set_passwords(mock_manager, names, password_gen_options)
      expect( @output.string ).to eq(expected_output)
    end

    it 'gathers passwords from the user and then sets them' do
      passwords = []
      names.each do |name|
        passwords << "#{name}_new_password"
      end

      allow(Simp::Cli::Passgen::Utils).to receive(:get_password)
        .with(5, false, 8).and_return(*passwords)

      mock_manager = object_double('Mock Password Manager', {
        :set_password => nil,
        :location     => "'production' Environment"
      })

      password_options = { :auto_gen => false, :validate => false,
        :minimum_length => 8 }

      names.each do |name|
        options = { :password => "#{name}_new_password" }
        options.merge!(password_options)
        allow(mock_manager).to receive(:set_password).
          with(name, options).and_return(options[:password])
      end

      expected_output = <<~EOM
        Processing 'name1' in 'production' Environment... done.
          'name1' new password: name1_new_password

        Processing 'name2' in 'production' Environment... done.
          'name2' new password: name2_new_password

        Processing 'name3' in 'production' Environment... done.
          'name3' new password: name3_new_password

        Processing 'name4' in 'production' Environment... done.
          'name4' new password: name4_new_password

      EOM

      @setter.set_passwords(mock_manager, names, password_options)
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

      expected_stdout = <<~EOM
        Processing 'name1' in 'production' Environment... done.
          'name1' new password: name1_new_password

        Processing 'name2' in 'production' Environment... done.
          Skipped 'name2'

        Processing 'name3' in 'production' Environment... done.
          Skipped 'name3'

        Processing 'name4' in 'production' Environment... done.
          'name4' new password: name4_new_password

      EOM

      expected_err_msg = <<~EOM
Failed to set 2 out of 4 passwords in 'production' Environment:
  'name2': Set failed: permission denied
  'name3': Set failed: connection timed out
      EOM

      expect { @setter.set_passwords(mock_manager, names, password_gen_options) }
        .to raise_error(
        Simp::Cli::ProcessingError,
        expected_err_msg.strip)
      expect( @output.string ).to eq(expected_stdout)
    end
  end

  #
  # Simp::Cli::Commands::Command API methods
  #
  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Passgen::Set.description}/
      expect{ @setter.help }.to output(expected_stdout_regex).to_stdout
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
        expect { @setter.run(['name1', '-e', 'oops']) }.to raise_error(
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
          .with(@module_list_command_prod, false, @setter.logger)
          .and_return(module_list_results)

        expect { @setter.run(['name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Invalid Puppet environment 'production': " +
          'simp-simplib is not installed')
      end

      it 'fails when LegacyPasswordManager cannot be constructed' do
        allow(@setter).to receive(:get_simplib_version).and_return('3.0.0')
        password_env_dir = File.join(@var_dir, 'simp', 'environments')
        default_password_dir = File.join(password_env_dir, 'production',
          'simp_autofiles', 'gen_passwd')

        FileUtils.mkdir_p(File.dirname(default_password_dir))
        FileUtils.touch(default_password_dir)
        expect { @setter.run(['name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{default_password_dir}' is not a directory")
      end
    end

    # This test verifies that the correct password manager object has been
    # instantiated and used with appropriate options from the command line
    # in Simp::Cli::Commands::Passgen::Set#set_passwords.
    describe 'using password manager' do
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
            .with(@module_list_command_prod, false, @setter.logger)
            .and_return(@old_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @setter.logger)
            .and_return(@old_simplib_module_list_results)
        end

        it 'sets passwords for names in default env using default options' do
          allow(Simp::Cli::Passgen::Utils).to receive(:get_password)
            .with(5, false, 8)
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

          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Processing 'name1' in 'production' Environment... done.
              'name1' new password: name1_new_password

            Processing 'name2' in 'production' Environment... done.
              'name2' new password: name2_new_password

          EOM

          @setter.run(['name1,name2'])
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

          expected_output = <<~EOM
            Initializing for environment 'dev'... done.
            Processing 'name1' in 'dev' Environment... done.
              'name1' new password: name1_new_password

          EOM

          @setter.run(['name1'] + custom_args)
          expect( @output.string ).to eq(expected_output)
        end

        it 'sets passwords for names in specified directory' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :set_password => nil,
            :location  => '/some/passgen/path'
          })

          allow(mock_manager).to receive(:set_password)
            .with('name1', custom_options).and_return('name1_new_password')

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('dev', '/some/passgen/path').and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'dev'... done.
            Processing 'name1' in /some/passgen/path... done.
              'name1' new password: name1_new_password

          EOM

          @setter.run(['name1', '-d', '/some/passgen/path'] + custom_args)
          expect( @output.string ).to eq(expected_output)
        end
      end

      context 'current manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @setter.logger)
            .and_return(@new_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @setter.logger)
            .and_return(@new_simplib_module_list_results)
        end

        it 'sets passwords for names in default env using default options' do
          allow(Simp::Cli::Passgen::Utils).to receive(:get_password)
            .with(5, false, 8)
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

          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Processing 'name1' in 'production' Environment... done.
              'name1' new password: name1_new_password

            Processing 'name2' in 'production' Environment... done.
              'name2' new password: name2_new_password

          EOM

          @setter.run(['name1,name2'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'sets passwords for names in specified env using custom options' do
          mock_manager = object_double('Mock PasswordManager', {
            :set_password => nil,
            :location     =>
              "'dev' Environment, 'backend3' simpkv Backend"
          })

          allow(mock_manager).to receive(:set_password)
            .with('name1', custom_options).and_return('name1_new_password')

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('dev', 'backend3', nil).and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'dev'... done.
            Processing 'name1' in 'dev' Environment, 'backend3' simpkv Backend... done.
              'name1' new password: name1_new_password

          EOM

          @setter.run([ 'name1', '--backend', 'backend3'] + custom_args)
          expect( @output.string ).to eq(expected_output)
        end
      end
    end

    describe 'option validation' do
      it 'requires non-empty name list' do
        expect { @setter.run([]) }.to raise_error(
          Simp::Cli::ProcessingError,
          'Password names are missing from command line')
      end
    end
  end
end
