require 'simp/cli/commands/passgen'
require 'simp/cli/lib/utils'
require 'spec_helper'
require 'etc'


def validate_set_and_backup(args, expected_output, expected_password_files,
    expected_passwords)
  expect { Simp::Cli::Commands::Passgen.run(args) }.to output(expected_output).to_stdout

  expected_password_files.each do |file|
    expect(File.exist?(file)).to eq true
  end

  actual_passwords = []
  expected_password_files.each do |file|
    actual_passwords << IO.read(file).chomp
  end

  expected_passwords.each_index do |index|
    expect(actual_passwords[index]).to eq expected_passwords[index]
  end
end

describe Simp::Cli::Commands::Passgen do
  describe ".run" do
    before :each do
      @tmp_dir   = Dir.mktmpdir(File.basename(__FILE__))
      @var_dir = File.join(@tmp_dir, 'vardir')
      @password_env_dir = File.join(@var_dir, 'simp', 'environments')
      FileUtils.mkdir_p(@password_env_dir)
      allow(Simp::Cli::Commands::Passgen).to receive(:`).with('puppet config print vardir --section master').and_return(@var_dir  + "\n")
      process_user = Etc.getpwuid(Process.uid).name
      process_group = Etc.getgrgid(Process.gid).name
      allow(Simp::Cli::Commands::Passgen).to receive(:`).with('puppet config print user').and_return(process_user)
      allow(Simp::Cli::Commands::Passgen).to receive(:`).with('puppet config print group').and_return(process_group)
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
      Simp::Cli::Commands::Passgen.reset_options
    end

    describe '--list-env option' do
      it 'lists no environments, when no environments exist' do
        expected_output = <<EOM
Environments:
	

EOM
        expect { Simp::Cli::Commands::Passgen.run(['--list-env']) }.to output(expected_output).to_stdout
      end

      it 'lists available environments' do
        FileUtils.mkdir(File.join(@password_env_dir, 'production'))
        FileUtils.mkdir(File.join(@password_env_dir, 'env1'))
        FileUtils.mkdir(File.join(@password_env_dir, 'env2'))
        expected_output = <<EOM
Environments:
	env1
	env2
	production

EOM
        expect { Simp::Cli::Commands::Passgen.run(['-E']) }.to output(expected_output).to_stdout
      end

      it 'fails when environments cannot be determined from password dir option' do
        expect { Simp::Cli::Commands::Passgen.run(['-E', '-d', @tmp_dir]) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password environment directory could not be determined from '#{@tmp_dir}'")
      end

      it 'fails when environment directory does not exist' do
        FileUtils.rm_rf(@password_env_dir)
        expect { Simp::Cli::Commands::Passgen.run(['-E']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password environment directory '#{@password_env_dir}' does not exist")
      end

      it 'fails when environment directory is not a directory' do
        FileUtils.rm_rf(@password_env_dir)
        FileUtils.touch(@password_env_dir)
        expect { Simp::Cli::Commands::Passgen.run(['-E']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password environment directory '#{@password_env_dir}' is not a directory")
      end
    end

    describe '--list-name option' do
      before :each do
        @default_password_dir = File.join(@password_env_dir, 'production', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(@default_password_dir)
      end

      it 'lists no password names, when no names exist' do
        expected_output = <<EOM
production Names:
	

EOM
        expect { Simp::Cli::Commands::Passgen.run(['--list-name']) }.to output(expected_output).to_stdout
      end

      it 'lists available names for default environment' do
        FileUtils.touch(File.join(@default_password_dir, 'production_name1'))
        FileUtils.touch(File.join(@default_password_dir, 'production_name2'))
        FileUtils.touch(File.join(@default_password_dir, 'production_name3'))
        expected_output = <<EOM
production Names:
	production_name1
	production_name2
	production_name3

EOM
        expect { Simp::Cli::Commands::Passgen.run(['-l']) }.to output(expected_output).to_stdout
      end

      it 'lists available names for specified environment' do
        password_dir = File.join(@password_env_dir, 'env1', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(password_dir)
        FileUtils.touch(File.join(password_dir, 'env1_name1'))
        expected_output = <<EOM
env1 Names:
	env1_name1

EOM
        expect { Simp::Cli::Commands::Passgen.run(['-l', '-e', 'env1']) }.to output(expected_output).to_stdout
      end

      it 'fails when password directory does not exist' do
        FileUtils.rm_rf(@default_password_dir)
        expect { Simp::Cli::Commands::Passgen.run(['-l']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' does not exist")
      end

      it 'fails when password directory is not a directory' do
        FileUtils.rm_rf(@default_password_dir)
        FileUtils.touch(@default_password_dir)
        expect { Simp::Cli::Commands::Passgen.run(['-l']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' is not a directory")
      end

    end

    describe '--name option' do
      before :each do
        @default_password_dir = File.join(@password_env_dir, 'production', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(@default_password_dir)
        @name1_file = File.join(@default_password_dir, 'production_name1')
        File.open(@name1_file, 'w') { |file| file.puts "production_name1_password" }
        @name1_backup_file = File.join(@default_password_dir, 'production_name1.last')
        File.open(@name1_backup_file, 'w') { |file| file.puts "production_name1_backup_password" }
        @name2_file = File.join(@default_password_dir, 'production_name2')
        File.open(@name2_file, 'w') { |file| file.puts "production_name2_password" }
        @name3_file = File.join(@default_password_dir, 'production_name3')
        File.open(@name3_file, 'w') { |file| file.puts "production_name3_password" }
        @name3_backup_file = File.join(@default_password_dir, 'production_name3.last')
        File.open(@name3_backup_file, 'w') { |file| file.puts "production_name3_backup_password" }
      end

      it 'shows current and previous passwords for specified names of default environment' do
        expected_output = <<EOM
production Environment
======================
Name: production_name2
  Current:  production_name2_password

Name: production_name3
  Current:  production_name3_password
  Previous: production_name3_backup_password

EOM
        expect { Simp::Cli::Commands::Passgen.run(['--name', 'production_name2,production_name3']) }.to output(expected_output).to_stdout
      end

      it 'shows current and previous passwords for specified names of specified environment' do
        password_dir = File.join(@password_env_dir, 'env1', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(password_dir)
        name1_file = File.join(password_dir, 'env1_name1')
        File.open(name1_file, 'w') { |file| file.puts "env1_name1_password" }
        name1_backup_file = File.join(password_dir, 'env1_name1.last')
        File.open(name1_backup_file, 'w') { |file| file.puts "env1_name1_backup_password" }
        expected_output = <<EOM
env1 Environment
================
Name: env1_name1
  Current:  env1_name1_password
  Previous: env1_name1_backup_password

EOM
        expect { Simp::Cli::Commands::Passgen.run(['-e', 'env1', '-n', 'env1_name1']) }.to output(expected_output).to_stdout
      end

      it 'fails when no names specified' do
        expect { Simp::Cli::Commands::Passgen.run(['-n']) }.to raise_error(OptionParser::MissingArgument)
      end

      it 'fails when invalid name specified' do
        expect { Simp::Cli::Commands::Passgen.run(['-n', 'oops']) }.to raise_error(
          OptionParser::ParseError,
          /Invalid name 'oops' selected.\n\nValid names: production_name1, production_name2, production_name3/)
      end

      it 'fails when password directory does not exist' do
        FileUtils.rm_rf(@default_password_dir)
        expect { Simp::Cli::Commands::Passgen.run(['-n', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' does not exist")
      end

      it 'fails when password directory is not a directory' do
        FileUtils.rm_rf(@default_password_dir)
        FileUtils.touch(@default_password_dir)
        expect { Simp::Cli::Commands::Passgen.run(['-n', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' is not a directory")
      end
    end

    describe '--set option' do
      before :each do
        @default_password_dir = File.join(@password_env_dir, 'production', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(@default_password_dir)
        @name1_file = File.join(@default_password_dir, 'production_name1')
        File.open(@name1_file, 'w') { |file| file.puts "production_name1_password" }
        @name1_backup_file = File.join(@default_password_dir, 'production_name1.last')
        File.open(@name1_backup_file, 'w') { |file| file.puts "production_name1_backup_password" }
        @name2_file = File.join(@default_password_dir, 'production_name2')
        File.open(@name2_file, 'w') { |file| file.puts "production_name2_password" }
        @name3_file = File.join(@default_password_dir, 'production_name3')
        File.open(@name3_file, 'w') { |file| file.puts "production_name3_password" }
        @name3_backup_file = File.join(@default_password_dir, 'production_name3.last')
        File.open(@name3_backup_file, 'w') { |file| file.puts "production_name3_backup_password" }

        @env1_password_dir = File.join(@password_env_dir, 'env1', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(@env1_password_dir)
        @name4_file = File.join(@env1_password_dir, 'env1_name4')
        File.open(@name4_file, 'w') { |file| file.puts "env1_name4_password" }
        @name4_backup_file = File.join(@env1_password_dir, 'env1_name4.last')
        File.open(@name4_backup_file, 'w') { |file| file.puts "env1_name4_backup_password" }
      end

      context 'with default environment' do
        context 'with backups' do
          let(:expected_passwords) { [
            'new_password',
            'production_name1_password',
            'new_password',
            'production_name2_password',
            'production_name3_password',       # unchanged
            'production_name3_backup_password' # unchanged
          ] }

          let(:expected_password_files) { [
            @name1_file,
            @name1_backup_file,
            @name2_file,
            @name2_file + '.last',
            @name3_file,
            @name3_backup_file
          ] }

          it 'updates password file and backs up old file per prompt' do
            allow(::Utils).to receive(:get_password).and_return('new_password')
            allow(STDIN).to receive(:gets) { 'y' }
            expected_output = <<EOM
production Name: production_name1
Would you like to rotate the old password? [y|N]: 
production Name: production_name2
Would you like to rotate the old password? [y|N]: 
EOM
            validate_set_and_backup(['-s', 'production_name1,production_name2' ],
              expected_output, expected_password_files, expected_passwords)
          end

          it 'updates password file and backs up old file per --backup option' do
            allow(::Utils).to receive(:get_password).and_return('new_password')
            expected_output = <<EOM
production Name: production_name1

production Name: production_name2

EOM
            validate_set_and_backup(['--backup', '-s', 'production_name1,production_name2' ],
              expected_output, expected_password_files, expected_passwords)
          end
        end

        context 'without backups' do
          let(:expected_passwords) { [
            'new_password',
            'production_name1_backup_password',
            'new_password',
            'production_name3_password',
            'production_name3_backup_password'
          ] }

          let(:expected_password_files) { [
            @name1_file,
            @name1_backup_file,
            @name2_file,
            @name3_file,
            @name3_backup_file
          ] }

          it 'updates password file and does not back up old file per prompt' do
            allow(::Utils).to receive(:get_password).and_return('new_password')
            allow(STDIN).to receive(:gets) { 'n' }
            expected_output = <<EOM
production Name: production_name1
Would you like to rotate the old password? [y|N]: 
production Name: production_name2
Would you like to rotate the old password? [y|N]: 
EOM
            validate_set_and_backup(['-s', 'production_name1,production_name2' ],
              expected_output, expected_password_files, expected_passwords)

            expect(File.exist?(@name2_file + '.last')).to eq false
          end

          it 'updates password file and does not back up old file per --no-backup option' do
            allow(::Utils).to receive(:get_password).and_return('new_password')
            expected_output = <<EOM
production Name: production_name1

production Name: production_name2

EOM
            validate_set_and_backup(['--no-backup', '-s', 'production_name1,production_name2' ],
              expected_output, expected_password_files, expected_passwords)

            expect(File.exist?(@name2_file + '.last')).to eq false
          end
        end

        it 'creates password file for new name' do
          allow(::Utils).to receive(:get_password).and_return('new_password')
          expected_output = <<EOM
production Name: new_name

EOM
          expect { Simp::Cli::Commands::Passgen.run(['--backup', '-s', 'new_name']) }.to output(
            expected_output).to_stdout
          new_password_file = File.join(@default_password_dir, 'new_name')
          expect( File.exist?(new_password_file) ).to eq true
          expect( File.exist?(new_password_file + '.last') ).to eq false
          expect( IO.read(new_password_file).chomp ).to eq 'new_password'
        end

        it 'allows multiple backups' do
          allow(::Utils).to receive(:get_password).and_return('new_password')
          Simp::Cli::Commands::Passgen.run(['--backup', '-s', 'production_name1'])
          expect { Simp::Cli::Commands::Passgen.run(['--backup', '-s', 'production_name1']) }.not_to raise_error
          expect { Simp::Cli::Commands::Passgen.run(['--backup', '-s', 'production_name1']) }.not_to raise_error
       end
      end

      context 'specified environment' do
        context 'with backups' do
          let(:expected_passwords) { [
            'new_password',
            'env1_name4_password'
          ] }

          let(:expected_password_files) { [
            @name4_file,
            @name4_backup_file
          ] }

          it 'updates password file and backs up old file per prompt' do
            allow(::Utils).to receive(:get_password).and_return('new_password')
            allow(STDIN).to receive(:gets) { 'y' }
            expected_output = <<EOM
env1 Name: env1_name4
Would you like to rotate the old password? [y|N]: 
EOM
            validate_set_and_backup(['-e', 'env1', '-s', 'env1_name4'],
              expected_output, expected_password_files, expected_passwords)
          end

          it 'updates password file and backs up old file per --backup option' do
            allow(::Utils).to receive(:get_password).and_return('new_password')
            expected_output = <<EOM
env1 Name: env1_name4

EOM
            validate_set_and_backup(['-e', 'env1', '--backup', '-s', 'env1_name4' ],
              expected_output, expected_password_files, expected_passwords)
          end
        end

        context 'without backups' do
          let(:expected_passwords) { [
            'new_password',
            'env1_name4_backup_password'
          ] }

          let(:expected_password_files) { [
            @name4_file,
            @name4_backup_file
          ] }

          it 'updates password file and does not back up old file per prompt' do
            allow(::Utils).to receive(:get_password).and_return('new_password')
            allow(STDIN).to receive(:gets) { 'n' }
            expected_output = <<EOM
env1 Name: env1_name4
Would you like to rotate the old password? [y|N]: 
EOM
            validate_set_and_backup(['-e', 'env1', '-s', 'env1_name4' ],
              expected_output, expected_password_files, expected_passwords)

            expect(File.exist?(@name2_file + '.last')).to eq false
          end

          it 'updates password file and does not back up old file per --no-backup option' do
            allow(::Utils).to receive(:get_password).and_return('new_password')
            expected_output = <<EOM
env1 Name: env1_name4

EOM
            validate_set_and_backup(['-e', 'env1', '--no-backup', '-s', 'env1_name4' ],
              expected_output, expected_password_files, expected_passwords)
          end
        end

        it 'creates password file for new name' do
          allow(::Utils).to receive(:get_password).and_return('new_password')
          expected_output = <<EOM
env1 Name: new_name

EOM
          expect { Simp::Cli::Commands::Passgen.run(['-e', 'env1', '--backup', '-s', 'new_name']) }.to output(
            expected_output).to_stdout
          new_password_file = File.join(@env1_password_dir, 'new_name')
          expect( File.exist?(new_password_file) ).to eq true
          expect( File.stat(new_password_file).mode & 0777 ).to eq 0640
          expect( File.exist?(new_password_file + '.last') ).to eq false
          expect( IO.read(new_password_file).chomp ).to eq 'new_password'
        end
      end

      it 'fails when no names specified' do
        expect { Simp::Cli::Commands::Passgen.run(['-s']) }.to raise_error(OptionParser::MissingArgument)
      end

      it 'fails when password directory does not exist' do
        FileUtils.rm_rf(@default_password_dir)
        expect { Simp::Cli::Commands::Passgen.run(['-s', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' does not exist")
      end

      it 'fails when password directory is not a directory' do
        FileUtils.rm_rf(@default_password_dir)
        FileUtils.touch(@default_password_dir)
        expect { Simp::Cli::Commands::Passgen.run(['-s', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' is not a directory")
      end
    end

    describe '--remove option' do
      before :each do
        @default_password_dir = File.join(@password_env_dir, 'production', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(@default_password_dir)
        @name1_file = File.join(@default_password_dir, 'production_name1')
        File.open(@name1_file, 'w') { |file| file.puts "production_name1_password" }
        @name1_backup_file = File.join(@default_password_dir, 'production_name1.last')
        File.open(@name1_backup_file, 'w') { |file| file.puts "production_name1_backup_password" }
        @name2_file = File.join(@default_password_dir, 'production_name2')
        File.open(@name2_file, 'w') { |file| file.puts "production_name2_password" }
        @name3_file = File.join(@default_password_dir, 'production_name3')
        File.open(@name3_file, 'w') { |file| file.puts "production_name3_password" }
        @name3_backup_file = File.join(@default_password_dir, 'production_name3.last')
        File.open(@name3_backup_file, 'w') { |file| file.puts "production_name3_backup_password" }

        @env1_password_dir = File.join(@password_env_dir, 'env1', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(@env1_password_dir)
        @name4_file = File.join(@env1_password_dir, 'env1_name4')
        File.open(@name4_file, 'w') { |file| file.puts "env1_name4_password" }
        @name4_backup_file = File.join(@env1_password_dir, 'env1_name4.last')
        File.open(@name4_backup_file, 'w') { |file| file.puts "env1_name4_backup_password" }
      end

      context 'with default environment' do
        it 'removes password files, including backup files when prompt returns yes' do
          allow(STDIN).to receive(:gets) { 'y' }
          expected_output = <<EOM
Are you sure you want to remove all entries for production_name1? [y|N]: #{@name1_backup_file} deleted
#{@name1_file} deleted

Are you sure you want to remove all entries for production_name2? [y|N]: #{@name2_file} deleted

EOM
          expect { Simp::Cli::Commands::Passgen.run(['-r',
            'production_name1,production_name2' ]) }.to output(expected_output).to_stdout

          expect(File.exist?(@name1_file)).to eq false
          expect(File.exist?(@name1_backup_file)).to eq false
          expect(File.exist?(@name2_file)).to eq false
          expect(File.exist?(@name3_file)).to eq true
          expect(File.exist?(@name3_backup_file)).to eq true
        end

        it 'does not remove password files, including backup files when prompt returns no' do
          allow(STDIN).to receive(:gets) { 'N' }
          expected_output = <<EOM
Are you sure you want to remove all entries for production_name1? [y|N]: 
Are you sure you want to remove all entries for production_name2? [y|N]: 
EOM
          expect { Simp::Cli::Commands::Passgen.run(['-r',
            'production_name1,production_name2' ]) }.to output(expected_output).to_stdout

          expect(File.exist?(@name1_file)).to eq true
          expect(File.exist?(@name1_backup_file)).to eq true
          expect(File.exist?(@name2_file)).to eq true
          expect(File.exist?(@name3_file)).to eq true
          expect(File.exist?(@name3_backup_file)).to eq true
        end

        it 'removes password files, including backup files, without prompting with --force-remove option' do
          expected_output = <<EOM
#{@name1_backup_file} deleted
#{@name1_file} deleted

#{@name2_file} deleted

EOM
          expect { Simp::Cli::Commands::Passgen.run(['-r', 'production_name1,production_name2',
            '--force-remove']) }.to output(expected_output).to_stdout

          expect(File.exist?(@name1_file)).to eq false
          expect(File.exist?(@name1_backup_file)).to eq false
          expect(File.exist?(@name2_file)).to eq false
          expect(File.exist?(@name3_file)).to eq true
          expect(File.exist?(@name3_backup_file)).to eq true
        end
      end

      context 'specified environment' do
        it 'removes password files, including backup files, per prompt' do
          allow(STDIN).to receive(:gets) { 'yes' }
          expected_output = <<EOM
Are you sure you want to remove all entries for env1_name4? [y|N]: #{@name4_backup_file} deleted
#{@name4_file} deleted

EOM
          expect { Simp::Cli::Commands::Passgen.run(['-e', 'env1', '-r',
            'env1_name4']) }.to output(expected_output).to_stdout

          expect(File.exist?(@name4_file)).to eq false
          expect(File.exist?(@name4_backup_file)).to eq false

        end

        it 'does not remove password files, including backup files, per prompt' do
          allow(STDIN).to receive(:gets) { 'no' }
          expected_output = <<EOM
Are you sure you want to remove all entries for env1_name4? [y|N]: 
EOM
          expect { Simp::Cli::Commands::Passgen.run(['-e', 'env1', '-r',
            'env1_name4']) }.to output(expected_output).to_stdout

          expect(File.exist?(@name4_file)).to eq true
          expect(File.exist?(@name4_backup_file)).to eq true
        end

        it 'removes password files, including backup files, without prompting with --force-remove option' do
          expected_output = <<EOM
#{@name4_backup_file} deleted
#{@name4_file} deleted

EOM
          expect { Simp::Cli::Commands::Passgen.run(['-e', 'env1', '-r', 'env1_name4',
            '--force-remove']) }.to output(expected_output).to_stdout

          expect(File.exist?(@name4_file)).to eq false
          expect(File.exist?(@name4_backup_file)).to eq false
        end
      end

      it 'fails when no names specified' do
        expect { Simp::Cli::Commands::Passgen.run(['-r']) }.to raise_error(OptionParser::MissingArgument)
      end

      it 'fails when invalid names specified' do
        expect { Simp::Cli::Commands::Passgen.run(['-r', 'production_name1,oops,production_name2']) }.to raise_error(
          OptionParser::ParseError,
          /Invalid name 'oops' selected.\n\nValid names: production_name1, production_name2/)
      end

      it 'fails when password directory does not exist' do
        FileUtils.rm_rf(@default_password_dir)
        expect { Simp::Cli::Commands::Passgen.run(['-r', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' does not exist")
      end

      it 'fails when password directory is not a directory' do
        FileUtils.rm_rf(@default_password_dir)
        FileUtils.touch(@default_password_dir)
        expect { Simp::Cli::Commands::Passgen.run(['-r', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' is not a directory")
      end
    end

    describe 'option validation' do
      it 'requires operation option to be specified' do
        expect { Simp::Cli::Commands::Passgen.run([]) }.to raise_error(OptionParser::ParseError,
          /The SIMP Passgen Tool requires at least one option/)

        expect { Simp::Cli::Commands::Passgen.run(['-e', 'production']) }.to raise_error(OptionParser::ParseError,
          /No password operation specified./)
      end
    end
  end
end
