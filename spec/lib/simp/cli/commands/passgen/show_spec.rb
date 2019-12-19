require 'simp/cli/commands/passgen'
require 'simp/cli/commands/passgen/show'
require 'simp/cli/passgen/legacy_password_manager'
require 'simp/cli/passgen/password_manager'

require 'etc'
require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Commands::Passgen::Show do
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
    @shower = Simp::Cli::Commands::Passgen::Show.new

    # make sure notice and above messages are output
    @shower.set_up_global_logger(0)
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
  describe '#show_password_info' do
    let(:names) { [ 'name1', 'name2', 'name3', 'name4' ] }

    context 'with brief reporting' do
      it 'lists current and previous passwords for names' do
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

        expected_output = <<~EOM
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

        @shower.show_password_info(mock_manager, names, false)
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

        expected_stdout = <<~EOM
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

        expected_err_msg = <<~EOM
          Failed to retrieve 2 out of 4 passwords in 'production' Environment:
            'name2': Set failed: permission denied
            'name3': Set failed: connection timed out
        EOM

        expect { @shower.show_password_info(mock_manager, names, false) }.to raise_error(
          Simp::Cli::ProcessingError, expected_err_msg.strip)

        expect( @output.string ).to eq(expected_stdout)
      end
    end

    context 'with detailed reporting' do
      it 'lists all available password info for names' do
        mock_manager = object_double('Mock Password Manager', {
          :password_info => nil,
          :location      => "'production' Environment"
        })

        # full set of info with history, as would be from a passgen entry in libkv
        allow(mock_manager).to receive(:password_info).with('name1').and_return(
          {
            'value' => {
              'password' => 'name1_password', 'salt' => 'name1_salt'
            },
            'metadata' => {
              'complexity'   => 0,
              'complex_only' => false,
              'history'      =>
                [
                  [ 'name1_password_minus_1', 'name1_salt_minus_1'],
                  [ 'name1_password_minus_2', 'name1_salt_minus_2']
                ]
            }
          }
        )

        # full set of info with empty history, as would be from a passgen entry in libkv
        allow(mock_manager).to receive(:password_info).with('name2').and_return(
          {
            'value' => {
              'password' => 'name2_password', 'salt' => 'name2_salt'
            },
            'metadata' => {
              'complexity'   => 1,
              'complex_only' => true,
              'history'      => []
            }
          }
        )

        # partial set of info with history, as would be from a legacy passgen entry
        allow(mock_manager).to receive(:password_info).with('name3').and_return(
          {
            'value' => { 'password' => 'name3_password', 'salt' => 'name3_salt' },
            'metadata' => {
              'history'  => [ [ 'name3_password_minus_1', 'name3_salt_minus_1'] ]
            }
          }
        )

        # partial set of info with empty history, as would be from a legacy passgen entry
        allow(mock_manager).to receive(:password_info).with('name4').and_return(
          {
            'value' => { 'password' => 'name4_password', 'salt' => 'UNKNOWN' },
            'metadata' => { 'history'  => [] }
          }
        )

        expected_output = <<~EOM
          Retrieving password information... done.

          'production' Environment Passwords
          ==================================
          Name: name1
            Password:     name1_password
            Salt:         name1_salt
            Length:       14
            Complexity:   0
            Complex-Only: false
            History:
              Password: name1_password_minus_1
              Salt:     name1_salt_minus_1
              Password: name1_password_minus_2
              Salt:     name1_salt_minus_2

          Name: name2
            Password:     name2_password
            Salt:         name2_salt
            Length:       14
            Complexity:   1
            Complex-Only: true

          Name: name3
            Password:     name3_password
            Salt:         name3_salt
            Length:       14
            History:
              Password: name3_password_minus_1
              Salt:     name3_salt_minus_1

          Name: name4
            Password:     name4_password
            Salt:         UNKNOWN
            Length:       14
        EOM

        @shower.show_password_info(mock_manager, names, true)
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
              'metadata' => {
                'complexity'   => 0,
                'complex_only' => false,
                'history'      => [
                  [ "#{name}_password_last", "#{name}_salt_last"]
                ]
              }
            }
          )
        end

        allow(mock_manager).to receive(:password_info).with('name2').
          and_raise(Simp::Cli::ProcessingError, 'Set failed: permission denied')

        allow(mock_manager).to receive(:password_info).with('name3').
          and_raise(Simp::Cli::ProcessingError,
         'Set failed: connection timed out')

        expected_stdout = <<~EOM
          Retrieving password information... done.

          'production' Environment Passwords
          ==================================
          Name: name1
            Password:     name1_password
            Salt:         name1_salt
            Length:       14
            Complexity:   0
            Complex-Only: false
            History:
              Password: name1_password_last
              Salt:     name1_salt_last

          Name: name2
            Skipped

          Name: name3
            Skipped

          Name: name4
            Password:     name4_password
            Salt:         name4_salt
            Length:       14
            Complexity:   0
            Complex-Only: false
            History:
              Password: name4_password_last
              Salt:     name4_salt_last
        EOM

        expected_err_msg = <<~EOM
          Failed to retrieve 2 out of 4 passwords in 'production' Environment:
            'name2': Set failed: permission denied
            'name3': Set failed: connection timed out
        EOM

        expect { @shower.show_password_info(mock_manager, names, true) }.to raise_error(
          Simp::Cli::ProcessingError, expected_err_msg.strip)

        expect( @output.string ).to eq(expected_stdout)
      end
    end
  end

  #
  # Simp::Cli::Commands::Command API methods
  #
  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Passgen::Show.description}/
      expect{ @shower.help }.to output(expected_stdout_regex).to_stdout
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
        expect { @shower.run(['name1', '-e', 'oops']) }.to raise_error(
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
          .with(@module_list_command_prod, false, @shower.logger)
          .and_return(module_list_results)

        expect { @shower.run(['name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Invalid Puppet environment 'production': " +
          'simp-simplib is not installed')
      end

      it 'fails when LegacyPasswordManager cannot be constructed' do
        allow(@shower).to receive(:get_simplib_version).and_return('3.0.0')
        password_env_dir = File.join(@var_dir, 'simp', 'environments')
        default_password_dir = File.join(password_env_dir, 'production',
          'simp_autofiles', 'gen_passwd')

        FileUtils.mkdir_p(File.dirname(default_password_dir))
        FileUtils.touch(default_password_dir)
        expect { @shower.run(['name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{default_password_dir}' is not a directory")
      end
    end

    # This test verifies that the correct password manager object has been
    # instantiated and used in Simp::Cli::Commands::Passgen::Show#show_password_info.
    describe 'using password manager' do
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
            .with(@module_list_command_prod, false, @shower.logger)
            .and_return(@old_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @shower.logger)
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

          expected_output = <<~EOM
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

          @shower.run(['name1,name2'])
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
          expected_output = <<~EOM
            Initializing for environment 'dev'... done.
            Retrieving password information... done.

            'dev' Environment Passwords
            ===========================
            Name: name1
              Current:  password1
              Previous: password1_old
          EOM

          @shower.run(['name1', '-e', 'dev'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists passwords for specified names in specified directory' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :password_info => nil,
            :location      => '/some/passgen/path'
          })

          allow(mock_manager).to receive(:password_info).with('name1')
            .and_return(password_info1)

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', '/some/passgen/path').and_return(mock_manager)
          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Retrieving password information... done.

            /some/passgen/path Passwords
            ============================
            Name: name1
              Current:  password1
              Previous: password1_old
          EOM

          @shower.run(['name1', '-d', '/some/passgen/path'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists full password info for specified names when --details specified' do
          mock_manager = object_double('Mock LegacyPasswordManager', {
            :password_info => nil,
            :location      => "'production' Environment"
          })

          allow(mock_manager).to receive(:password_info).with('name1')
            .and_return(password_info1)

          allow(Simp::Cli::Passgen::LegacyPasswordManager).to receive(:new)
            .with('production', nil).and_return(mock_manager)
          expected_output = <<~EOM
            Initializing for environment 'production'... done.
            Retrieving password information... done.

            'production' Environment Passwords
            ==================================
            Name: name1
              Password:     password1
              Salt:         salt1
              Length:       9
              Complex-Only: false
              History:
                Password: password1_old
                Salt:     salt1_old
                Password: password1_old_old
                Salt:     salt1_old_old
          EOM

          @shower.run(['name1', '--details'])
          expect( @output.string ).to eq(expected_output)
        end
      end

      context 'current manager' do
        before :each do
          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_prod, false, @shower.logger)
            .and_return(@new_simplib_module_list_results)

          allow(Simp::Cli::ExecUtils).to receive(:run_command)
            .with(@module_list_command_dev, false, @shower.logger)
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

          expected_output = <<~EOM
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

          @shower.run(['name1,name2'])
          expect( @output.string ).to eq(expected_output)
        end

        it 'lists passwords for specified names in specified <env,backend>' do

          mock_manager = object_double('Mock PasswordManager', {
            :password_info => nil,
            :location      =>
              "'dev' Environment, 'backend3' libkv Backend"
          })

          allow(mock_manager).to receive(:password_info).with('name1')
            .and_return(password_info1)

          allow(Simp::Cli::Passgen::PasswordManager).to receive(:new)
            .with('dev', 'backend3', nil).and_return(mock_manager)

          expected_output = <<~EOM
            Initializing for environment 'dev'... done.
            Retrieving password information... done.

            'dev' Environment, 'backend3' libkv Backend Passwords
            =====================================================
            Name: name1
              Current:  password1
              Previous: password1_old
          EOM

          @shower.run(['name1', '-e', 'dev', '--backend', 'backend3'])

          expect( @output.string ).to eq(expected_output)
        end
      end
    end

    describe 'option validation' do
      it 'requires a password name list' do
        expect { @shower.run([]) }.to raise_error(
          Simp::Cli::ProcessingError,
          'Password names are missing from command line')
      end
    end
  end
end
