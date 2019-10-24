require 'simp/cli/passgen/legacy_password_manager'

require 'etc'
require 'spec_helper'
require 'tmpdir'

require 'test_utils/legacy_passgen'
include TestUtils::LegacyPassgen

describe Simp::Cli::Passgen::LegacyPasswordManager do
  before :each do
    @tmp_dir   = Dir.mktmpdir(File.basename(__FILE__))
    @var_dir = File.join(@tmp_dir, 'vardir')
    @password_env_dir = File.join(@var_dir, 'simp', 'environments')
    FileUtils.mkdir_p(@password_env_dir)
    @env = 'production'
    @password_dir = File.join(@password_env_dir, @env, 'simp_autofiles',
      'gen_passwd')

    @alt_password_dir = File.join(@password_env_dir, 'gen_passwd')
    @user  = Etc.getpwuid(Process.uid).name
    @group = Etc.getgrgid(Process.gid).name
    puppet_info = {
      :config => {
        'user'   => @user,
        'group'  => @group,
        'vardir' => @var_dir
      }
    }

    allow(Simp::Cli::Utils).to receive(:puppet_info).with(@env)
      .and_return(puppet_info)

    @manager = Simp::Cli::Passgen::LegacyPasswordManager.new(@env)
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir, true
  end

  describe 'initialize errors' do
    it 'fails when password directory is not a directory' do
      FileUtils.mkdir_p(File.dirname(@password_dir))
      FileUtils.touch(@password_dir)
      expect { Simp::Cli::Passgen::LegacyPasswordManager.new(@env) }
        .to raise_error( Simp::Cli::ProcessingError,
        "Password directory '#{@password_dir}' is not a directory")
    end
  end

  #
  # Password Manager API tests
  #
  describe 'location' do
    it 'returns string with env when custom dir is not specified' do
      expect( @manager.location ).to eq("'#{@env}' Environment")
    end

    it 'returns string with custom dir when specified' do
      manager = Simp::Cli::Passgen::LegacyPasswordManager.new(@env,
        @alt_password_dir)

      expect( manager.location ).to eq(@alt_password_dir)
    end
  end

  describe '#name_list' do
    it 'returns empty array  when no names exist' do
      FileUtils.mkdir_p(@password_dir)
      expect( @manager.name_list ).to eq([])
    end

    it 'returns list of available names for the specified env' do
      names = ['production_name', '10.0.1.2', 'salt.and.pepper', 'my.last.name']
      create_password_files(@password_dir, names)
      expected = [
        '10.0.1.2',
        'my.last.name',
        'production_name',
        'salt.and.pepper'
      ]
      expect( @manager.name_list ).to eq(expected)
    end

    it 'returns list of available names for a specified password dir' do
      names = ['app1_user', 'app2_user' ]
      create_password_files(@alt_password_dir, names)
      manager = Simp::Cli::Passgen::LegacyPasswordManager.new(@env,
        @alt_password_dir)

      expected = [ 'app1_user', 'app2_user' ]
      expect( manager.name_list ).to eq(expected)
    end

    it 'fails when password directory cannot be accessed' do
      FileUtils.mkdir_p(@password_dir)
      allow(Dir).to receive(:chdir).with(@password_dir).and_raise(
         Errno::EACCES, 'failed chdir')

      expect { @manager.name_list }.to raise_error( Simp::Cli::ProcessingError,
        'List failed: Permission denied - failed chdir')
    end

  end

  describe '#password_info' do
    before :each do
      names_with_backup = ['production_name1', 'production_name3']
      names_without_backup = ['production_name2']
      create_password_files(@password_dir, names_with_backup,
        names_without_backup)
    end

    it 'returns hash with full info for name with all files in specified env' do
      expected = {
        'value'    => {
          'password' => 'production_name3_password',
          'salt'     => 'salt for production_name3'
        },
          'metadata' => {
          'history' => [
            [
              'production_name3_backup_password',
              'salt for production_name3 backup'
            ]
          ]
        }
      }

      expect( @manager.password_info('production_name3') ).to eq(expected)
    end

    it 'returns hash with partial info for name with subset of files in ' +
       'specified env' do

      expected = {
        'value'    => {
          'password' => 'production_name2_password',
          'salt'     => 'salt for production_name2'
        },
          'metadata' => {
          'history' => []
        }
      }

      expect( @manager.password_info('production_name2') ).to eq(expected)
    end

    it 'returns hash with info for name in specified password dir' do
      create_password_files(@alt_password_dir, ['env1_name1'])
      manager = Simp::Cli::Passgen::LegacyPasswordManager.new(@env,
        @alt_password_dir)

      expected = {
        'value'    => {
          'password' => 'env1_name1_password',
          'salt'     => 'salt for env1_name1'
        },
          'metadata' => {
          'history' => [
            ['env1_name1_backup_password', 'salt for env1_name1 backup' ]
          ]
        }
      }

      expect( manager.password_info('env1_name1') ).to eq(expected)
    end

    it 'fails when non-existent name specified' do
      expect { @manager.password_info('oops') }.to raise_error(
        Simp::Cli::ProcessingError, "'oops' password not present")
    end

    it 'fails when password file cannot be read' do
      unreadable_file = File.join(@password_dir, 'production_name1')
      allow(File).to receive(:read).with(any_args).and_call_original
      allow(File).to receive(:read).with(unreadable_file).and_raise(
        Errno::EACCES, 'failed read')

      expect { @manager.password_info('production_name1') }.to raise_error(
        Simp::Cli::ProcessingError,
        "Retrieve failed: Permission denied - failed read")
    end

  end

  describe '#remove_password' do
    before :each do
      names_with_backup = ['production_name1', 'production_name3']
      names_without_backup = ['production_name2']
      create_password_files(@password_dir, names_with_backup,
        names_without_backup)

      @name1_file = File.join(@password_dir, 'production_name1')
      @name1_salt_file = File.join(@password_dir, 'production_name1.salt')
      @name1_backup_file = File.join(@password_dir, 'production_name1.last')
      @name1_backup_salt_file = File.join(@password_dir,
        'production_name1.salt.last')

      @name2_file = File.join(@password_dir, 'production_name2')
      @name2_salt_file = File.join(@password_dir, 'production_name2.salt')

      @name3_file = File.join(@password_dir, 'production_name3')
      @name3_salt_file = File.join(@password_dir, 'production_name3.salt')
      @name3_backup_file = File.join(@password_dir, 'production_name3.last')
      @name3_backup_salt_file = File.join(@password_dir,
        'production_name3.salt.last')
    end

    it 'removes password, backup, and salt files for name specified env' do
      @manager.remove_password('production_name1')

      expect(File.exist?(@name1_file)).to eq false
      expect(File.exist?(@name1_salt_file)).to eq false
      expect(File.exist?(@name1_backup_file)).to eq false
      expect(File.exist?(@name1_backup_salt_file)).to eq false
      expect(File.exist?(@name2_file)).to eq true
      expect(File.exist?(@name2_salt_file)).to eq true
      expect(File.exist?(@name3_file)).to eq true
      expect(File.exist?(@name3_salt_file)).to eq true
      expect(File.exist?(@name3_backup_file)).to eq true
      expect(File.exist?(@name3_backup_salt_file)).to eq true

      @manager.remove_password('production_name2')

      expect(File.exist?(@name2_file)).to eq false
      expect(File.exist?(@name2_salt_file)).to eq false
    end

    it 'removes password, backup, and salt files in specified password dir' do
      create_password_files(@alt_password_dir, ['env1_name4'])


      manager = Simp::Cli::Passgen::LegacyPasswordManager.new(@env,
        @alt_password_dir)

      manager.remove_password('env1_name4')

      expect(File.exist?(File.join(@alt_password_dir, 'env1_name4'))).to eq false
      expect(File.exist?(File.join(@alt_password_dir, 'env1_name4.salt'))).to eq false
      expect(File.exist?(File.join(@alt_password_dir, 'env1_name4.last'))).to eq false
      expect(File.exist?(File.join(@alt_password_dir, 'env1_name4.salt.last'))).to eq false
    end

    it 'removes residual files when password file missing' do
      File.unlink(@name1_file)
      @manager.remove_password('production_name1')

      expect(File.exist?(@name1_salt_file)).to eq false
      expect(File.exist?(@name1_backup_file)).to eq false
      expect(File.exist?(@name1_backup_salt_file)).to eq false
    end

    it 'deletes all accessible files and fails with list of delete failures' do
      allow(File).to receive(:unlink).with(any_args).and_call_original
      unreadable_files = [ @name1_file, @name1_salt_file ]
      unreadable_files.each do |file|
        allow(File).to receive(:unlink).with(file).and_raise(
          Errno::EACCES, 'failed delete')
      end

      expected_err_msg = <<-EOM
Failed to delete the following password files:
  '#{unreadable_files[0]}': Permission denied - failed delete
  '#{unreadable_files[1]}': Permission denied - failed delete
      EOM

      names = ['production_name1', 'production_name2', 'production_name3']
      expect { @manager.remove_password('production_name1') }.to raise_error(
        Simp::Cli::ProcessingError, expected_err_msg.strip)
    end

    it 'fails when no files for the name exist' do
      expect { @manager.remove_password('oops') }.to raise_error(
        Simp::Cli::ProcessingError, "'oops' password not found")
    end

  end

  describe '#set_password' do
    before :each do
      names_with_backup = ['production_name1', 'production_name3']
      names_without_backup = ['production_name2']
      create_password_files(@password_dir, names_with_backup,
        names_without_backup)

      @name1_file = File.join(@password_dir, 'production_name1')
      @name1_salt_file = File.join(@password_dir, 'production_name1.salt')
      @name1_backup_file = File.join(@password_dir, 'production_name1.last')
      @name1_backup_salt_file = File.join(@password_dir,
       'production_name1.salt.last')

      @name2_file = File.join(@password_dir, 'production_name2')
      @name2_salt_file = File.join(@password_dir, 'production_name2.salt')
      @name2_backup_file = File.join(@password_dir, 'production_name2.last')
      @name2_backup_salt_file = File.join(@password_dir,
       'production_name2.salt.last')

      @name3_file = File.join(@password_dir, 'production_name3')
      @name3_salt_file = File.join(@password_dir, 'production_name3.salt')
      @name3_backup_file = File.join(@password_dir, 'production_name3.last')
      @name3_backup_salt_file = File.join(@password_dir,
       'production_name3.salt.last')
    end

    let(:options) do
      {
        :auto_gen             => false,
        :validate             => false,
        :default_length       => 32,
        :minimum_length       => 8,
        :default_complexity   => 0,
        :default_complex_only => false
      }
    end

    it 'updates password file, backs up old files, and returns new password ' +
       'for name in the specified env' do

      # bypass password input
      allow(@manager).to receive(:get_new_password).and_return(
        ['first_new_password', false], ['second_new_password', false])

      expect( @manager.set_password('production_name1', options) )
        .to eq('first_new_password')

      expect( @manager.set_password('production_name2', options) )
        .to eq('second_new_password')

      expected_file_info = {
        # new password, no salt, and full backup
        @name1_file             => 'first_new_password',
        @name1_salt_file        => nil,
        @name1_backup_file      => 'production_name1_password',
        @name1_backup_salt_file => 'salt for production_name1',

        # new password, no salt, and full backup
        @name2_file             => 'second_new_password',
        @name2_salt_file        => nil,
        @name2_backup_file      => 'production_name2_password',
        @name2_backup_salt_file => 'salt for production_name2',

        # unchanged
        @name3_file             => 'production_name3_password',
        @name3_salt_file        => 'salt for production_name3',
        @name3_backup_file      => 'production_name3_backup_password',
        @name3_backup_salt_file => 'salt for production_name3 backup'
      }

      validate_files(expected_file_info)
    end

    it 'updates password file, and backs up old files, and returns new ' +
       'password for name in the specified password dir' do

      create_password_files(@alt_password_dir, ['env1_name4'])

      manager = Simp::Cli::Passgen::LegacyPasswordManager.new(@env,
        @alt_password_dir)

      allow(manager).to receive(:get_new_password)
        .and_return(['new_password',false])

      expect( manager.set_password('env1_name4', options) ).to eq('new_password')

      expected_file_info = {
        # new password, no salt, and full backup
        File.join(@alt_password_dir, 'env1_name4')           => 'new_password',
        File.join(@alt_password_dir, 'env1_name4.salt')      => nil,
        File.join(@alt_password_dir, 'env1_name4.last')      => 'env1_name4_password',
        File.join(@alt_password_dir, 'env1_name4.salt.last') => 'salt for env1_name4'
      }

      validate_files(expected_file_info)
    end

    it 'creates and sets a new password with same length as old password ' +
       'when auto_gen=true' do

      new_opts = options.dup
      new_opts[:auto_gen] = true
      new_password = @manager.set_password('production_name1', new_opts)
      expect(new_password.length).to eq('production_name1_password'.length)

      expected_file_info = {
        # new password, no salt, and full backup
        @name1_file             => new_password,
        @name1_salt_file        => nil,
        @name1_backup_file      => 'production_name1_password',
        @name1_backup_salt_file => 'salt for production_name1',
      }

      validate_files(expected_file_info)
    end

    it 'creates password file for new name' do
      allow(@manager).to receive(:get_new_password)
        .and_return(['new_password',false])

      expect( @manager.set_password('new_name', options) ).to eq('new_password')

      expected_file_info = {
        # new password, no salt or backup
        File.join(@password_dir, 'new_name')           => 'new_password',
        File.join(@password_dir, 'new_name.salt')      => nil,
        File.join(@password_dir, 'new_name.last')      => nil,
        File.join(@password_dir, 'new_name.salt.last') => nil
      }

      validate_files(expected_file_info)
    end

    it 'allows multiple backups' do
      allow(@manager).to receive(:get_new_password)
        .and_return(['new_password',false])

      expect { @manager.set_password('name1', options) }.not_to raise_error
      expect { @manager.set_password('name1', options) }.not_to raise_error
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
        Simp::Cli::ProcessingError, 'Missing :auto_gen option')
    end

    it 'fails if merge_password_options fails' do
      allow(@manager).to receive(:merge_password_options).and_raise(
        Simp::Cli::ProcessingError, 'Error occurred while reading')

      expect { @manager.set_password('new_name', options) }.to raise_error(
        Simp::Cli::ProcessingError, 'Set failed: Error occurred while reading')
    end

    it 'fails if get_new_password fails' do
      allow(@manager).to receive(:get_new_password).and_raise(
        Simp::Cli::ProcessingError,
        'FATAL: Too many failed attempts to enter password')

      expect { @manager.set_password('new_name', options) }.to raise_error(
        Simp::Cli::ProcessingError,
        'Set failed: FATAL: Too many failed attempts to enter password')
    end

    it 'fails if backup_password_files fails' do
      allow(@manager).to receive(:get_new_password)
        .and_return(['new_password',false])

      allow(@manager).to receive(:backup_password_files).and_raise(
        Simp::Cli::ProcessingError, 'Error occurred while backing up')

      expect { @manager.set_password('production_name1', options) }
        .to raise_error( Simp::Cli::ProcessingError,
        'Set failed: Error occurred while backing up')
    end

    it 'fails if cannot make password dir when it does not exist' do
      FileUtils.rm_rf(@password_dir)
      allow(@manager).to receive(:get_new_password)
        .and_return(['new_password',false])

      allow(FileUtils).to receive(:mkdir_p).with(any_args).and_call_original
      allow(FileUtils).to receive(:mkdir_p).with(@password_dir).and_raise(
         Errno::EACCES, 'failed mkdir_p')

      expect { @manager.set_password('new_name', options) }.to raise_error(
        Simp::Cli::ProcessingError,
        'Set failed: Permission denied - failed mkdir_p')
    end

    it 'fails if it cannot write to password file' do
      allow(@manager).to receive(:get_new_password)
        .and_return(['new_password',false])

      allow(File).to receive(:open).with(any_args).and_call_original
      allow(File).to receive(:open).with(@name1_file, 'w').and_raise(
        Errno::EACCES, 'failed password file write')

      expect { @manager.set_password('production_name1', options) }
        .to raise_error( Simp::Cli::ProcessingError,
        'Set failed: Permission denied - failed password file write')
    end

    it 'fails if it cannot chown password file' do
      allow(@manager).to receive(:get_new_password)
        .and_return(['new_password',false])

      allow(FileUtils).to receive(:chown).with(any_args).and_call_original
      allow(FileUtils).to receive(:chown).with(@user, @group, @name1_file)
        .and_raise(ArgumentError, 'failed password file chown')

      expect { @manager.set_password('production_name1', options) }
        .to raise_error( Simp::Cli::ProcessingError,
        'Set failed: failed password file chown')
    end
  end


  #
  # Helper tests.  Since most helper methods are fully tested in Password
  # Manager API tests, only use cases not otherwise tested are exercised here.
  #
  describe '#backup_password_files' do
    before :each do
      create_password_files(@password_dir, ['name1'])
      @name1_file = File.join(@password_dir, 'name1')
      @name1_salt_file = File.join(@password_dir, 'name1.salt')
      @name1_backup_file = File.join(@password_dir, 'name1.last')
      @name1_backup_salt_file = File.join(@password_dir, 'name1.salt.last')
    end

    it 'fails if password file cannot be backed up' do
      allow(FileUtils).to receive(:mv).with(any_args).and_call_original
      allow(FileUtils).to receive(:mv).with(@name1_file, @name1_backup_file,
        :force => true).and_raise(
        Errno::EACCES, 'failed password file move')

      expect { @manager.backup_password_files(@name1_file) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Error occurred while backing up 'name1': " +
        "Permission denied - failed password file move")
    end

    it 'fails if salt file cannot be backed up' do
      allow(FileUtils).to receive(:mv).with(any_args).and_call_original
      allow(FileUtils).to receive(:mv).with(@name1_salt_file,
        @name1_backup_salt_file, :force => true).and_raise(
        Errno::EACCES, 'failed salt file move')

      expect { @manager.backup_password_files(@name1_file) }
        .to raise_error( Simp::Cli::ProcessingError,
        "Error occurred while backing up 'name1': " +
        "Permission denied - failed salt file move")
    end
  end

  describe '#get_new_password' do
    before :each do
      @input = StringIO.new
      @output = StringIO.new
      @prev_terminal = $terminal
      $terminal = HighLine.new(@input, @output)
    end

    after :each do
      @input.close
      @output.close
      $terminal = @prev_terminal
    end

    let(:good_password) { 'A=V3ry=Go0d=P@ssw0r!' }
    let(:bad_password) { 'password' }
    let(:short_password) { 'short' }

    let(:options) do
      {
        :auto_gen             => false,
        :validate             => false,
        :default_length       => 32,
        :minimum_length       => 8,
        :default_complexity   => 0,
        :default_complex_only => false,
        :length               => 24,
        :complexity           => 1,
        :complex_only         => true
      }
    end

    let(:default_chars) do
      (("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a).map do|x|
          x = Regexp.escape(x)
      end
    end

    let(:safe_special_chars) do
      ['@','%','-','_','+','=','~'].map do |x|
        x = Regexp.escape(x)
      end
    end

    it 'autogenerates a password with specified characteristics when ' +
       'auto_gen=true' do

      new_opts = options.dup
      new_opts[:auto_gen] = true
      password,generated = @manager.get_new_password(new_opts)
      expect( password.length ).to eq(options[:length])
      expect( password ).not_to match(/(#{default_chars.join('|')})/)
      expect( password ).to match(/(#{(safe_special_chars).join('|')})/)
      expect( generated ).to be(true)
    end

    it 'gathers and returns valid user password when auto_gen=false and ' +
       ':validate=true' do

      @input << "#{good_password}\n"
      @input << "#{good_password}\n"
      @input.rewind
      new_opts = options.dup
      new_opts[:validate] = true
      expect( @manager.get_new_password(new_opts)).to eq([good_password, false])
    end

    it 'gathers and returns insufficient complexity user password when ' +
       'auto_gen=false and validate=false' do

      @input << "#{bad_password}\n"
      @input << "#{bad_password}\n"
      @input.rewind
      expect( @manager.get_new_password(options)).to eq([bad_password, false])
    end

    it 'gathers and returns too short user password when auto_gen=false and ' +
       'validate=false' do

      @input << "#{short_password}\n"
      @input << "#{short_password}\n"
      @input.rewind
      expect( @manager.get_new_password(options)).to eq([short_password, false])
    end
  end

  describe '#merge_password_options' do
    before(:each) do
      FileUtils.mkdir_p(@password_dir)
      @name = 'name'
      @password_file = File.join(@password_dir, @name)
    end

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
        it 'returns options with :length=:default_length when password file ' +
           'does not exist' do

          merged_opts = @manager.merge_password_options(@password_file, options)
          expect( merged_opts[:length] ).to eq(options[:default_length])
        end

        it 'returns options with :length=existing valid password length' do
          File.open(@password_file, 'w') { |file| file.puts '12345678' }
          merged_opts = @manager.merge_password_options(@password_file, options)
          expect( merged_opts[:length] ).to eq(8)
        end

        it 'returns options with :length=:default_length when existing ' +
           'password length is too short' do

          File.open(@password_file, 'w') { |file| file.puts '1234567' }
          merged_opts = @manager.merge_password_options(@password_file, options)
          expect( merged_opts[:length] ).to eq(options[:default_length])
        end

        it 'fails if it cannot read existing password file' do
          File.open(@password_file, 'w') { |file| file.puts "name_password" }
          allow(File).to receive(:read).with(any_args).and_call_original
          allow(File).to receive(:read).with(@password_file).and_raise(
            Errno::EACCES, 'failed password file read')

          expect { @manager.merge_password_options(@password_file, options) }
            .to raise_error( Simp::Cli::ProcessingError,
            "Error occurred while reading '#{@password_file}': " +
            "Permission denied - failed password file read")
        end
      end

      context 'input :length option set' do
        it 'returns options with input :length when it exists and is valid' do
          new_opts = options.dup
          new_opts[:length] = 48
          merged_opts = @manager.merge_password_options(@password_file, new_opts)
          expect( merged_opts[:length] ).to eq(new_opts[:length])
        end

        it 'returns options with :length=:default_length when input options ' +
           ':length is too short' do
          new_opts = options.dup
          new_opts[:length] = 6
          merged_opts = @manager.merge_password_options(@password_file, new_opts)
          expect( merged_opts[:length] ).to eq(new_opts[:default_length])
        end
      end
    end

    context ':complexity option' do
      it 'returns options with input :complexity when it exists' do
        new_opts = options.dup
        new_opts[:length] = 64
        new_opts[:complexity] = 2
        merged_opts = @manager.merge_password_options(@password_file, new_opts)
        expect( merged_opts[:complexity] ).to eq(new_opts[:complexity])
      end

      it 'returns options with :complexity=:default_complexity when input ' +
         'missing :complexity' do

        new_opts = options.dup
        new_opts[:length] = 64
        merged_opts = @manager.merge_password_options(@password_file, new_opts)
        expect( merged_opts[:complexity] ).to eq(new_opts[:default_complexity])
      end
    end

    context ':complex_only option' do
      it 'returns options with input :complex_only when it exists' do
        new_opts = options.dup
        new_opts[:length] = 64
        new_opts[:complex_only] = true
        merged_opts = @manager.merge_password_options(@password_file, new_opts)
        expect( merged_opts[:complex_only] ).to eq(new_opts[:complex_only])
      end

      it 'returns options with :complex_only=:default_complex_only when ' +
         'input missing :complex_only' do

        new_opts = options.dup
        new_opts[:length] = 64
        merged_opts = @manager.merge_password_options(@password_file, new_opts)
        expect( merged_opts[:complex_only] ).to eq(new_opts[:default_complex_only])
      end
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

    it 'fails when :validate option missing' do
      bad_options = {
        :auto_gen             => false,
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
        :auto_gen             => false,
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
        :auto_gen             => false,
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
        :auto_gen             => false,
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
        :auto_gen           => false,
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
