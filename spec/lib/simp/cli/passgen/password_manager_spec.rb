require 'simp/cli/passgen/password_manager'

require 'etc'
require 'spec_helper'

# ***WARNING***: Many tests in this file heavily make use of mocked behavior
# because the fundamental underlying operations, exec'ing `puppet apply`
# calls and reading files in transient directories, are not easily unit
# tested.  Full testing will be done in a detailed acceptance test!

describe Simp::Cli::Passgen::PasswordManager do
  before :each do
    @user  = Etc.getpwuid(Process.uid).name
    @group = Etc.getgrgid(Process.gid).name
    @env = 'production'
    puppet_info = {
      :config => {
        'user'   => @user,
        'group'  => @group,
        'vardir' => '/server/var/dir'
      }
    }
    allow(Simp::Cli::Utils).to receive(:puppet_info).with(@env)
      .and_return(puppet_info)

    @manager = Simp::Cli::Passgen::PasswordManager.new(@env, nil, nil)

    # backend and folder are independent options, but can be tested at the
    # same time to no ill effect
    @backend = 'backend3'
    @folder = 'app1'
    @manager_custom = Simp::Cli::Passgen::PasswordManager.new(@env, @backend,
      @folder)

    @simple_name = 'name1'
    @complex_name = "#{@folder}/#{@simple_name}"
  end

  #
  # Password Manager API tests
  #
  describe 'location' do
    it 'returns string with only env when no backend or folder specified' do
      expect( @manager.location ).to eq("'#{@env}' Environment")
    end

    it 'returns string with env and backend when folder is not specified' do
      manager = Simp::Cli::Passgen::PasswordManager.new(@env, @backend, nil)
      expected = "'#{@env}' Environment, '#{@backend}' libkv Backend"
      expect( manager.location ).to eq(expected)
    end

    it 'returns string with env and folder when backend is not specified' do
      manager = Simp::Cli::Passgen::PasswordManager.new(@env, nil, @folder)
      expected = "'#{@env}' Environment, '#{@folder}' Folder"
      expect( manager.location ).to eq(expected)
    end

    it 'returns string with env, backend, and folder when all specified' do
      manager = Simp::Cli::Passgen::PasswordManager.new(@env, @backend, @folder)
      expected = "'#{@env}' Environment, '#{@folder}' Folder, " +
        "'#{@backend}' libkv Backend"

      expect( manager.location ).to eq(expected)
    end
  end

  describe '#name_list' do
    let(:password_list) { {
      'keys' => {
        'name1' => {
          'value'    => { 'password' => 'password1', 'salt' => 'salt1'},
          'metadata' => {
            'complex'      => 1,
            'complex_only' => false,
            'history'      => [
              ['password1_old', 'salt1_old'],
              ['password1_old_old', 'salt1_old_old']
            ]
          }
        },
        'name2' => {
          'value' => { 'password' => 'password2', 'salt' => 'salt2'},
          'metadata' => {
            'complex'      => 1,
            'complex_only' => false,
            'history'      => []
          }
        }
      }
    } }

    # NOTE: Since we are mocking Simp::...:PasswordManager#password_list,
    # the test cases for top folder and <env,folder,backend> are identical.  As
    # such, we have omitted the duplicate tests.

    it 'returns empty array when no names exist for the folder' do
      allow(@manager).to receive(:password_list).and_return({})
      expect(@manager.name_list).to eq([])
    end

    it 'returns list of available names for the folder of the specified env' do
      allow(@manager).to receive(:password_list).and_return(password_list)
      expect(@manager.name_list).to eq(['name1', 'name2'])
    end

    it 'fails when #password_list fails' do
      allow(@manager).to receive(:password_list).and_raise(
        Simp::Cli::ProcessingError, 'Password list retrieve failed')

      expect { @manager.name_list }.to raise_error(
        Simp::Cli::ProcessingError,
        'List failed: Password list retrieve failed')
    end
  end

  describe '#password_info' do
    let(:password_info) { {
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

    it 'returns hash with info for name in top folder of the specified env' do
      allow(@manager).to receive(:current_password_info)
        .with(@simple_name).and_return(password_info)

      expect( @manager.password_info('name1') ).to eq(password_info)
    end

    it 'returns hash with info for name in <env,folder,backend> ' do
      allow(@manager_custom).to receive(:current_password_info)
        .with(@complex_name).and_return(password_info)

      expect( @manager_custom.password_info('name1') ).to eq(password_info)
    end

    it 'fails when non-existent name specified' do
      allow(@manager).to receive(:current_password_info)
        .with('oops').and_return({})

      expect { @manager.password_info('oops') }.to raise_error(
        Simp::Cli::ProcessingError,
        "Retrieve failed: 'oops' password not found")
    end

    it 'fails when retrieved info fails validation' do
      bad_info = { 'keys' => {} }
      allow(@manager).to receive(:current_password_info)
        .with(@simple_name).and_return(bad_info)

      expect { @manager.password_info(@simple_name) }.to raise_error(
        Simp::Cli::ProcessingError,
        'Retrieve failed: Invalid result returned from ' +
        "simplib::passgen::get:\n\n#{bad_info}")
    end

    it 'fails when #current_password_info fails' do
      allow(@manager).to receive(:current_password_info)
        .with(@simple_name).and_raise(
        Simp::Cli::ProcessingError, 'Current password retrieve failed')

      expect { @manager.password_info(@simple_name) }.to raise_error(
        Simp::Cli::ProcessingError,
        'Retrieve failed: Current password retrieve failed')
    end

  end

  describe '#remove_password' do
    it 'removes password for name in the specified env' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      expect{ @manager.remove_password('name1') }.to_not raise_error
    end

    it 'removes password for name in <env,folder,backend>' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      expect{ @manager_custom.remove_password('name1') }.to_not raise_error
    end

    it 'fails when no password for the name exists' do
      err_msg = "Error: Evaluation Error: Error while evaluating a" +
        " Function Call, Password not found (location info)"

      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_raise(Simp::Cli::ProcessingError, err_msg)

      expect { @manager.remove_password('oops') }.to raise_error(
        Simp::Cli::ProcessingError,
        "Remove failed: 'oops' password not found")
    end

    it 'fails when puppet apply with remove operation fails' do
      err_msg = "Error: Evaluation Error: Error while evaluating a" +
        " Function Call, libkv Configuration Error for libkv::exists with..."

      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_raise(Simp::Cli::ProcessingError, err_msg)

      expect { @manager.remove_password('oops') }.to raise_error(
        Simp::Cli::ProcessingError,
        "Remove failed: #{err_msg}")
    end
  end

  describe '#set_password' do
    let(:new_password) { 'new_password' }
    let(:options) do
      {
        :auto_gen             => false,
        :password             => new_password,
        :validate             => false,
        :default_length       => 32,
        :minimum_length       => 8,
        :default_complexity   => 0,
        :default_complex_only => false,
        # set length, complexity, and complex_only because we are mocking
        # #merge_password_options
        :length               => 48,
        :complexity           => 1,
        :complex_only         => true
      }
    end


    it 'calls #get_and_set_password and returns user-provided password for ' +
       'name in specified env when :auto_gen=false' do

      allow(@manager).to receive(:merge_password_options)
        .with(@simple_name, options).and_return(options)

      allow(@manager).to receive(:get_and_set_password)
        .with(@simple_name, options).and_return(new_password)

      expect( @manager.set_password(@simple_name, options) )
        .to eq(new_password)
    end

    it 'calls #get_and_set_password and returns user-provided password for ' +
       'name in <env,folder,backend> when :auto_gen=false' do

      allow(@manager_custom).to receive(:merge_password_options)
        .with(@complex_name, options).and_return(options)

      allow(@manager_custom).to receive(:get_and_set_password)
        .with(@complex_name, options).and_return(new_password)

      expect( @manager_custom.set_password(@simple_name, options) )
        .to eq(new_password)
    end

    it 'calls #generate_and_set_password and returns new password for name ' +
       'in the specified env when :auto_gen=true' do

      new_opts = options.dup
      new_opts[:auto_gen] = true
      allow(@manager).to receive(:merge_password_options)
        .with(@simple_name, new_opts).and_return(new_opts)

      allow(@manager).to receive(:generate_and_set_password)
        .with(@simple_name, new_opts).and_return(new_password)

      expect( @manager.set_password(@simple_name, new_opts) )
        .to eq(new_password)
    end

    it 'calls #generate_and_set_password and returns new password for name ' +
       'in the <env,folder,backend> when :auto_gen=true' do

      new_opts = options.dup
      new_opts[:auto_gen] = true
      allow(@manager_custom).to receive(:merge_password_options)
        .with(@complex_name, new_opts).and_return(new_opts)

      allow(@manager_custom).to receive(:generate_and_set_password)
        .with(@complex_name, new_opts).and_return(new_password)

      expect( @manager_custom.set_password(@simple_name, new_opts) )
        .to eq(new_password)
    end

    it 'fails when options is missing a required key' do
      bad_options = {
        :validate             => false,
        :default_length       => 32,
        :minimum_length       => 8,
        :default_complexity   => 0,
        :default_complex_only => false
      }
      expect { @manager.set_password('name1', bad_options) }.to raise_error(
        Simp::Cli::ProcessingError,
        'Missing :auto_gen option')
    end

    it 'fails if #merge_password_options fails for name in specified env' do
      allow(@manager).to receive(:merge_password_options)
        .with(@simple_name, options)
        .and_raise(Simp::Cli::ProcessingError,
        'Current password retrieve failed')

      expect { @manager.set_password(@simple_name, options) }.to raise_error(
        Simp::Cli::ProcessingError,
        'Set failed: Current password retrieve failed')
    end

    it 'fails if #merge_password_options fails for name in ' +
       '<env,folder,backend>' do

      allow(@manager_custom).to receive(:merge_password_options)
        .with(@complex_name, options)
        .and_raise(Simp::Cli::ProcessingError,
        'Current password retrieve failed')

      expect { @manager_custom.set_password(@simple_name, options) }
        .to raise_error(Simp::Cli::ProcessingError,
        'Set failed: Current password retrieve failed')
    end

    it 'fails if #get_and_set_password fails' do
      allow(@manager).to receive(:merge_password_options)
        .with(@simple_name, options).and_return(options)

      allow(@manager).to receive(:get_and_set_password)
        .with(@simple_name, options).and_raise(Simp::Cli::ProcessingError,
        'Password set failed')

      expect { @manager.set_password(@simple_name, options) }.to raise_error(
        Simp::Cli::ProcessingError,
        'Set failed: Password set failed')
    end

    it 'fails if #generate_and_set_password fails' do
      new_opts = options.dup
      new_opts[:auto_gen] = true
      allow(@manager).to receive(:merge_password_options)
        .with(@simple_name, new_opts).and_return(new_opts)

      allow(@manager).to receive(:generate_and_set_password)
        .with(@simple_name, new_opts).and_raise(Simp::Cli::ProcessingError,
        'Password generate and set failed')

      expect { @manager.set_password(@simple_name, new_opts) }
        .to raise_error(Simp::Cli::ProcessingError,
        'Set failed: Password generate and set failed')
    end
  end


  #
  # Helper tests.  Since most helper methods are tested in Password
  # Manager API tests, only use cases not otherwise tested are exercised here.
  #
  describe '#current_password_info' do
    let(:password_info) { {
      'value'    => { 'password' => 'password1', 'salt' => 'salt' },
      'metadata' => { 'history'  => [] }
    } }

    it 'applies manifest to retrieve password info and then returns it' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      allow(Simp::Cli::Passgen::Utils).to receive(:load_yaml)
        .and_return(password_info)

      expect( @manager.current_password_info(@simple_name) )
        .to eq(password_info)
    end

    it 'applies manifest with folder and backend to retrieve password info ' +
       'and then returns it' do

      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      allow(Simp::Cli::Passgen::Utils).to receive(:load_yaml)
        .and_return(password_info)

      expect( @manager_custom.current_password_info(@complex_name) )
        .to eq(password_info)
    end

    it 'fails when manifest apply fails' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_raise(Simp::Cli::ProcessingError, 'Password retrieve failed')

      expect{ @manager_custom.current_password_info(@complex_name) }
        .to raise_error(Simp::Cli::ProcessingError, 'Password retrieve failed')
    end

    it 'fails when interim password info YAML fails to load' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      allow(Simp::Cli::Passgen::Utils).to receive(:load_yaml).and_raise(
        Simp::Cli::ProcessingError, 'Failed to load password info YAML')

      expect{ @manager_custom.current_password_info(@complex_name) }
        .to raise_error(Simp::Cli::ProcessingError,
        'Failed to load password info YAML')
    end
  end

  describe '#generate_and_set_password' do
    let(:options) do
      {
        :length       => 32,
        :complexity   => 0,
        :complex_only => false
      }
    end

    let(:generated_password) { 'new generated password' }

    it 'applies manifest to generate and set <password,salt> and then ' +
       'returns generated password' do

      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      allow(File).to receive(:read).with(/password.txt$/).and_return(generated_password)

      expect( @manager.generate_and_set_password(@simple_name, options) )
        .to eq(generated_password)
    end

    it 'applies manifest with folder and backend to generate and set ' +
       '<password,salt> and then returns generated password' do

      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      allow(File).to receive(:read).with(/password.txt$/)
        .and_return(generated_password)

      expect( @manager_custom.generate_and_set_password(@complex_name, options) )
        .to eq(generated_password)
    end

    it 'fails when manifest apply fails' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest).and_raise(
        Simp::Cli::ProcessingError, 'Password generate and set failed')

      expect{ @manager.generate_and_set_password(@simple_name, options) }
        .to raise_error( Simp::Cli::ProcessingError,
        'Password generate and set failed')
    end

    it 'fails when interim password file cannot be read' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      allow(File).to receive(:read).with(/password.txt$/).and_raise(
         Errno::EACCES, 'password file read failed')

      expect{ @manager.generate_and_set_password(@simple_name, options) }
        .to raise_error( Simp::Cli::ProcessingError,
        'Failed to read generated password: ' +
        'Permission denied - password file read failed')
    end
  end

  describe '#get_and_set_password' do
    let(:user_input_password) { 'new password from user' }
    let(:options) do
      {
        :password     => user_input_password,
        :length       => 32,
        :complexity   => 0,
        :complex_only => false,
        :validate     => false
      }
    end


    it 'retrieves password from user, applies manifest to generate salt and set ' +
       'pair, and then returns password' do

      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      expect( @manager.get_and_set_password(@simple_name, options) )
        .to eq(user_input_password)
    end

    it 'retrieves password from user, applies manifest with folder and backend ' +
       'to generate salt and set pair, and then returns password' do

      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      expect( @manager_custom.get_and_set_password(@complex_name, options) )
        .to eq(user_input_password)
    end

    it 'fails when manifest apply fails' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_raise(Simp::Cli::ProcessingError, 'Password set failed')

      expect{ @manager.get_and_set_password(@simple_name, options) }
        .to raise_error( Simp::Cli::ProcessingError, 'Password set failed')
    end
  end

  describe '#merge_password_options' do

    let(:fullname) { 'name1' }
    let(:options) do
      {
        :default_length       => 32,
        :minimum_length       => 8,
        :default_complexity   => 0,
        :default_complex_only => false,
      }
    end

    context ':length option' do
      context 'input :length option unset' do
        it 'returns options with :length=:default_length when password does ' +
           'not exist' do

          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return({})

          merged_opts = @manager.merge_password_options(fullname, options)
          expect( merged_opts[:length] ).to eq(options[:default_length])
        end

        it 'returns options with :length=existing valid password length' do
          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return({ 'value' => { 'password' => '12345678'} })

          merged_opts = @manager.merge_password_options(fullname, options)
          expect( merged_opts[:length] ).to eq(8)
        end

        it 'returns options with :length=:default_length when existing ' +
           'password length is too short' do

          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return({ 'value' => { 'password' => '1234567'} })

          merged_opts = @manager.merge_password_options(fullname, options)
          expect( merged_opts[:length] ).to eq(options[:default_length])
        end
      end

      context 'input :length option set' do
        it 'returns options with input :length when it exists and is valid' do
          allow(@manager).to receive(:current_password_info).with(fullname)
              .and_return({ 'value' => { 'password' => '1234568'} })

          new_opts = options.dup
          new_opts[:length] = 48
          merged_opts = @manager.merge_password_options(fullname, new_opts)
          expect( merged_opts[:length] ).to eq(new_opts[:length])
        end

        it 'returns options with :length=:default_length when input options ' +
           ':length is too short' do

          allow(@manager).to receive(:current_password_info).with(fullname)
              .and_return({ 'value' => { 'password' => '1234568'} })

          new_opts = options.dup
          new_opts[:length] = 6
          merged_opts = @manager.merge_password_options(fullname, new_opts)
          expect( merged_opts[:length] ).to eq(new_opts[:default_length])
        end
      end
    end

    context ':complexity option' do
      context 'input :complexity option unset' do
        it 'returns options with :complexity=:default_complexity when ' +
           'password does not exist' do

          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return({})

          merged_opts = @manager.merge_password_options(fullname, options)
          expect( merged_opts[:complexity] ).to eq(options[:default_complexity])
        end

        it 'returns options with :complexity=:default_complexity when ' +
           'password exists but does not have complexity stored' do

          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return({ 'value' => { 'password' => '1234568'} })

          merged_opts = @manager.merge_password_options(fullname, options)
          expect( merged_opts[:complexity] ).to eq(options[:default_complexity])
        end

        it 'returns options with :complexity=existing password complexity' do
          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return(
            { 'value' => { 'password' => '1234568'},
              'metadata' => { 'complexity' => 2 }
            })

          merged_opts = @manager.merge_password_options(fullname, options)
          expect( merged_opts[:complexity] ).to eq(2)
        end
      end

      context 'input :complexity option set' do
        it 'returns options with input :complexity when it exists' do
          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return(
            { 'value' => { 'password' => '1234568'},
              'metadata' => { 'complexity' => 2 }
            })

          new_opts = options.dup
          new_opts[:complexity] = 1
          merged_opts = @manager.merge_password_options(fullname, new_opts)
          expect( merged_opts[:complexity] ).to eq(new_opts[:complexity])
        end
      end
    end

    context ':complex_only option' do
      context 'input :complex_only option unset' do
        it 'returns options with :complex_only=:default_complex_only when ' +
           'password does not exist' do

          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return({})
          merged_opts = @manager.merge_password_options(fullname, options)
          expect( merged_opts[:complex_only] ).to eq(options[:default_complex_only])
        end

        it 'returns options with :complex_only=:default_complex_only when ' +
           'password exists but does not have complex_only stored' do

          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return(
            { 'value' => { 'password' => '1234568'},
            })

          merged_opts = @manager.merge_password_options(fullname, options)
          expect( merged_opts[:complex_only] ).to eq(options[:default_complex_only])
        end

        it 'returns options with :complex_only=existing password complex_only' do
          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return(
            { 'value' => { 'password' => '1234568'},
              'metadata' => { 'complex_only' => true }
            })

          merged_opts = @manager.merge_password_options(fullname, options)
          expect( merged_opts[:complex_only] ).to be true
        end
      end

      context 'input :complex_only option set' do
        it 'returns options with input :complex_only when it exists' do
          allow(@manager).to receive(:current_password_info).with(fullname)
            .and_return(
            { 'value' => { 'password' => '1234568'},
              'metadata' => { 'complex_only' => false }
            })

          new_opts = options.dup
          new_opts[:complex_only] = true
          merged_opts = @manager.merge_password_options(fullname, new_opts)
          expect( merged_opts[:complex_only] ).to eq(new_opts[:complex_only])
        end
      end
    end

    context 'errors' do
      it 'fails if it puppet apply to get current password fails' do
        allow(@manager).to receive(:current_password_info).with(fullname)
          .and_raise(Simp::Cli::ProcessingError,
          'Current password retrieve failed')

        expect { @manager.merge_password_options(fullname, options) }
         .to raise_error(Simp::Cli::ProcessingError,
         'Current password retrieve failed')
      end
    end
  end

  describe '#password_list' do
    let(:password_list) { {
      'keys' => {
        'name1' => {
          'value'    => { 'password' => 'password1', 'salt' => 'salt1'},
          'metadata' => {
            'complex'      => 1,
            'complex_only' => false,
            'history'      => [
              ['password1_old', 'salt1_old'],
              ['password1_old_old', 'salt1_old_old']
            ]
          }
        },
        'name2' => {
          'value' => { 'password' => 'password2', 'salt' => 'salt2'},
          'metadata' => {
            'complex'      => 1,
            'complex_only' => false,
            'history'      => []
          }
        }
      }
    } }

    it 'applies manifest to retrieve password list and then returns it' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      allow(Simp::Cli::Passgen::Utils).to receive(:load_yaml)
        .and_return(password_list)

      expect( @manager.password_list ).to eq(password_list)
    end

    it 'applies manifest with folder and backend to retrieve password list ' +
           'and then returns it' do

      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      allow(Simp::Cli::Passgen::Utils).to receive(:load_yaml)
        .and_return(password_list)

      expect( @manager_custom.password_list ).to eq(password_list)
    end

    it 'fails when manifest apply fails' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_raise(Simp::Cli::ProcessingError, 'Password list retrieve failed')

      expect{ @manager_custom.password_list }.to raise_error(
        Simp::Cli::ProcessingError, 'Password list retrieve failed')
    end

    it 'fails when interim password list YAML fails to load' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      allow(Simp::Cli::Passgen::Utils).to receive(:load_yaml).and_raise(
        Simp::Cli::ProcessingError, 'Failed to load password list YAML')

      expect{ @manager_custom.password_list }.to raise_error(
        Simp::Cli::ProcessingError, 'Failed to load password list YAML')
    end

    it 'fails when retrieved password list is missing required keys' do
      allow(Simp::Cli::Passgen::Utils).to receive(:apply_manifest)
        .and_return({}) # don't care about return

      invalid_password_list = { 'oops' => {} }
      allow(Simp::Cli::Passgen::Utils).to receive(:load_yaml)
        .and_return(invalid_password_list)

      expect{ @manager_custom.password_list }.to raise_error(
        Simp::Cli::ProcessingError,
        'Invalid result returned from simplib::passgen::list:' +
        "\n\n#{invalid_password_list}")
    end
  end

  describe '#valid_password_list?' do
    it 'returns true if list hash is empty' do
      expect( @manager.valid_password_list?({}) ).to be true
    end

    it "returns true if list has required 'keys' key with an empty sub-hash" do
      list = { 'keys' => {} }
      expect( @manager.valid_password_list?(list) ).to be true
    end

    it "returns true if list has required 'keys' key with a valid sub-hash" do
      password_info = {
        'value'    => { 'password' => 'password1' },
        'metadata' => { 'history'  => [] }
      }

      list = { 'keys' => { 'name1' => password_info } }
      expect( @manager.valid_password_list?(list) ).to be true
    end

    it "returns false if list is missing required 'keys' key" do
      list = { 'folders' => [ 'app1', 'app2' ] }
      expect( @manager.valid_password_list?(list) ).to be false
    end

    it "returns false if list and invalid entry in the 'keys' sub-hash" do
      list = { 'keys' => { 'name1' => {} } }
      expect( @manager.valid_password_list?(list) ).to be false
    end
  end

  describe '#valid_password_info?' do
    it 'returns true if password info has required keys' do
      password_info = {
        'value'    => { 'password' => 'password1' },
        'metadata' => { 'history'  => [] }
      }

      expect( @manager.valid_password_info?(password_info) ).to be true
    end

    it "returns false if password info is missing 'value' key" do
      password_info = {
        'metadata' => { 'history' => [] }
      }

      expect( @manager.valid_password_info?(password_info) ).to be false
    end

    it "returns false if 'password' sub-key of 'value' is missing" do
      password_info = {
        'value'    => { 'salt'    => 'salt1' },
        'metadata' => { 'history' => [] }
      }

      expect( @manager.valid_password_info?(password_info) ).to be false
    end

    it "returns false if 'password' sub-key of 'value' is not a String" do
      password_info = {
        'value'    => { 'password' => ['password1'] },
        'metadata' => { 'history'  => [] }
      }

      expect( @manager.valid_password_info?(password_info) ).to be false
    end

    it "returns false if password info is missing 'metadata' key" do
      password_info = {
        'value'    => { 'password' => 'password1' }
      }

      expect( @manager.valid_password_info?(password_info) ).to be false
    end

    it "returns false if 'history' sub-key of 'metadata' is missing" do
      password_info = {
        'value'    => { 'password'   => 'password1' },
        'metadata' => { 'complexity' => 0 }
      }

      expect( @manager.valid_password_info?(password_info) ).to be false
    end

    it "returns false if 'history' sub-key of 'metadata' is not an Array" do
      password_info = {
        'value'    => { 'password' => 'password1' },
        'metadata' => { 'history' => { 'password' => 'old_password1' } }
      }

      expect( @manager.valid_password_info?(password_info) ).to be false
    end

  end

  describe '#validate_set_config' do
    it 'fails when :auto_gen option missing' do
      bad_options = {
        :validate             => false,
        :default_length       => 32,
        :minimum_length       => 8,
        :default_complexity   => 0,
        :default_complex_only => false
      }

      expect { @manager.validate_set_config(bad_options) }.to raise_error(
        Simp::Cli::ProcessingError, 'Missing :auto_gen option')
    end

    it 'fails when :password option missing and :auto_gen=true' do
      bad_options = {
        :auto_gen             => false,
        :validate             => false,
        :default_length       => 32,
        :minimum_length       => 8,
        :default_complexity   => 0,
        :default_complex_only => false
      }

      expect { @manager.validate_set_config(bad_options) }.to raise_error(
        Simp::Cli::ProcessingError, 'Missing :password option')
    end

    it 'fails when :validate option missing' do
      bad_options = {
        :auto_gen             => true,
        :default_length       => 32,
        :default_complexity   => 0,
        :default_complex_only => false,
        :minimum_length       => 8
      }

      expect { @manager.validate_set_config(bad_options) }.to raise_error(
        Simp::Cli::ProcessingError, 'Missing :validate option')
    end

    it 'fails when :default_length option missing' do
      bad_options = {
        :auto_gen             => true,
        :validate             => false,
        :minimum_length       => 8,
        :default_complexity   => 0,
        :default_complex_only => false
      }

      expect { @manager.validate_set_config(bad_options) }.to raise_error(
        Simp::Cli::ProcessingError, 'Missing :default_length option')
    end

    it 'fails when :minimum_length option missing' do
      bad_options = {
        :auto_gen             => true,
        :validate             => false,
        :default_length       => 32,
        :default_complexity   => 0,
        :default_complex_only => false
      }

      expect { @manager.validate_set_config(bad_options) }.to raise_error(
        Simp::Cli::ProcessingError, 'Missing :minimum_length option')
    end

    it 'fails when :default_complexity option missing' do
      bad_options = {
        :auto_gen             => true,
        :validate             => false,
        :minimum_length       => 8,
        :default_length       => 32,
        :default_complex_only => false
      }

      expect { @manager.validate_set_config(bad_options) }.to raise_error(
        Simp::Cli::ProcessingError, 'Missing :default_complexity option')
    end

    it 'fails when :default_complex_only option missing' do
      bad_options = {
        :auto_gen           => true,
        :validate           => false,
        :minimum_length     => 8,
        :default_length     => 32,
        :default_complexity => 0,
      }

      expect { @manager.validate_set_config(bad_options) }.to raise_error(
        Simp::Cli::ProcessingError, 'Missing :default_complex_only option')
    end
  end
end
