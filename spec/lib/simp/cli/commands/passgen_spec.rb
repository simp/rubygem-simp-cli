require 'simp/cli/commands/passgen'
require 'simp/cli/utils'
require 'spec_helper'
require 'etc'
require 'tmpdir'


def validate_set_and_backup(passgen, args, expected_output, expected_file_info)
  expect { passgen.run(args) }.to output(expected_output).to_stdout

  expected_file_info.each do |file,expected_contents|
    expect( File.exist?(file) ).to be true
    expect( IO.read(file).chomp ).to eq expected_contents
  end
end

describe Simp::Cli::Commands::Passgen do
  describe '#get_password' do
    before :each do
      @input = StringIO.new
      @output = StringIO.new
      @prev_terminal = $terminal
      $terminal = HighLine.new(@input, @output)

      @passgen = Simp::Cli::Commands::Passgen.new
    end

    after :each do
      @input.close
      @output.close
      $terminal = @prev_terminal
    end

    let(:password1) { 'A=V3ry=Go0d=P@ssw0r!' }

    it 'autogenerates a password when default is selected' do
      @input << "\n"
      @input.rewind
      expect( @passgen.get_password.length )
        .to eq Simp::Cli::Utils::DEFAULT_PASSWORD_LENGTH

      expected = '> Do you want to autogenerate the password?: |yes| '
      expect( @output.string.uncolor ).to eq expected
    end

    it "autogenerates a password when 'yes' is entered" do
      @input << "yes\n"
      @input.rewind
      expect( @passgen.get_password.length )
        .to eq Simp::Cli::Utils::DEFAULT_PASSWORD_LENGTH

      expected = '> Do you want to autogenerate the password?: |yes| '
      expect( @output.string.uncolor ).to eq expected
    end

    it 'does not prompt for autogenerate when allow_autogenerate=false' do
      @input << "#{password1}\n"
      @input << "#{password1}\n"
      @input.rewind
      expect( @passgen.get_password(false) ).to eq password1

      expected = <<EOM
> Enter password: ********************
> Confirm password: ********************
EOM
      expect( @output.string.uncolor ).to_not match /Do you want to autogenerate/
    end

    it 'accepts a valid password when entered twice' do
      @input << "no\n"
      @input << "#{password1}\n"
      @input << "#{password1}\n"
      @input.rewind
      expect( @passgen.get_password ).to eq password1

      expected = <<EOM
> Do you want to autogenerate the password?: |yes| > Enter password: ********************
> Confirm password: ********************
EOM
      expect(@output.string.uncolor).to eq expected
    end

    it 're-prompts when the entered password fails validation' do
      @input << "short\n"
      @input << "#{password1}\n"
      @input << "#{password1}\n"
      @input.rewind
      expect( @passgen.get_password(false) ).to eq password1

      expected = <<EOM
> Enter password: *****
> Enter password: ********************
> Confirm password: ********************
EOM
      expect(@output.string.uncolor).to eq expected
    end

    it 'starts over when the confirm password does not match the entered password' do
      @input << "#{password1}\n"
      @input << "bad confirm\n"
      @input << "#{password1}\n"
      @input << "#{password1}\n"
      @input.rewind
      expect( @passgen.get_password(false) ).to eq password1

      expected = <<EOM
> Enter password: ********************
> Confirm password: ***********
> Enter password: ********************
> Confirm password: ********************
EOM
      expect(@output.string.uncolor).to eq expected
    end

    it 'fails after 5 failed start-over attempts' do
      @input << "#{password1}\n"
      @input << "bad confirm 1\n"
      @input << "#{password1}\n"
      @input << "bad confirm 2\n"
      @input << "#{password1}\n"
      @input << "bad confirm 3\n"
      @input << "#{password1}\n"
      @input << "bad confirm 4\n"
      @input << "#{password1}\n"
      @input << "bad confirm 5\n"
      @input.rewind
      expect{ @passgen.get_password(false) }
        .to raise_error(Simp::Cli::ProcessingError)
    end

  end

  describe '#yes_or_no' do
    before :each do
      @input = StringIO.new
      @output = StringIO.new
      @prev_terminal = $terminal
      $terminal = HighLine.new(@input, @output)

      @passgen = Simp::Cli::Commands::Passgen.new
    end

    after :each do
      @input.close
      @output.close
      $terminal = @prev_terminal
    end

    it "when default_yes=true, prompts, accepts default of 'yes' and returns true" do
      @input << "\n"
      @input.rewind

      expect( @passgen.yes_or_no('Remove backups', true) ).to eq true
      expect( @output.string.uncolor ).to eq '> Remove backups: |yes| '
    end

    it "when default_yes=false, prompts, accepts default of 'no' and returns false" do
      @input << "\n"
      @input.rewind
      expect( @passgen.yes_or_no('Remove backups', false) ).to eq false
      expect( @output.string.uncolor ).to eq '> Remove backups: |no| '
    end

    ['yes', 'YES', 'y', 'Y'].each do |response|
      it "accepts '#{response}' and returns true" do
        @input << "#{response}\n"
        @input.rewind
        expect( @passgen.yes_or_no('Remove backups', false) ).to eq true
      end
    end

    ['no', 'NO', 'n', 'N'].each do |response|
      it "accepts '#{response}' and returns false" do
        @input << "#{response}\n"
        @input.rewind
        expect( @passgen.yes_or_no('Remove backups', false) ).to eq false
      end
    end

    it 're-prompts user when user does not enter a string that begins with Y, y, N, or n' do
      @input << "oops\n"
      @input << "I\n"
      @input << "can't\n"
      @input << "type!\n"
      @input << "yes\n"
      @input.rewind
      expect( @passgen.yes_or_no('Remove backups', false) ).to eq true
    end

  end

  describe '#run' do
    before :each do
      @tmp_dir   = Dir.mktmpdir(File.basename(__FILE__))
      @var_dir = File.join(@tmp_dir, 'vardir')
      @password_env_dir = File.join(@var_dir, 'simp', 'environments')
      FileUtils.mkdir_p(@password_env_dir)

      @passgen = Simp::Cli::Commands::Passgen.new

      allow(@passgen).to receive(:`).with('puppet config print vardir --section master 2>/dev/null').and_return(@var_dir  + "\n")
      process_user = Etc.getpwuid(Process.uid).name
      process_group = Etc.getgrgid(Process.gid).name
      allow(@passgen).to receive(:`).with('puppet config print user 2>/dev/null').and_return(process_user)
      allow(@passgen).to receive(:`).with('puppet config print group 2>/dev/null').and_return(process_group)
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir, true
    end

    describe '--list-env option' do
      it 'lists no environments, when no environments exist' do
        expected_output = <<EOM
Environments:
\t

EOM
        expect { @passgen.run(['--list-env']) }.to output(expected_output).to_stdout
      end

      it 'lists available environments' do
        FileUtils.mkdir(File.join(@password_env_dir, 'production'))
        FileUtils.mkdir(File.join(@password_env_dir, 'env1'))
        FileUtils.mkdir(File.join(@password_env_dir, 'env2'))
        expected_output = <<EOM
Environments:
\tenv1
\tenv2
\tproduction

EOM
        expect { @passgen.run(['-E']) }.to output(expected_output).to_stdout
      end

      it 'fails when environments cannot be determined from password dir option' do
        expect { @passgen.run(['-E', '-d', @tmp_dir]) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password environment directory could not be determined from '#{@tmp_dir}'")
      end

      it 'fails when environment directory does not exist' do
        FileUtils.rm_rf(@password_env_dir)
        expect { @passgen.run(['-E']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password environment directory '#{@password_env_dir}' does not exist")
      end

      it 'fails when environment directory is not a directory' do
        FileUtils.rm_rf(@password_env_dir)
        FileUtils.touch(@password_env_dir)
        expect { @passgen.run(['-E']) }.to raise_error(
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
\t

EOM
        expect { @passgen.run(['--list-name']) }.to output(expected_output).to_stdout
      end

      it 'lists available names for default environment' do
        FileUtils.touch(File.join(@default_password_dir, 'production_name'))
        FileUtils.touch(File.join(@default_password_dir, 'production_name.salt'))
        FileUtils.touch(File.join(@default_password_dir, 'production_name.last'))
        FileUtils.touch(File.join(@default_password_dir, 'production_name.salt.last'))
        FileUtils.touch(File.join(@default_password_dir, '10.0.1.2'))
        FileUtils.touch(File.join(@default_password_dir, 'salt.and.pepper'))
        FileUtils.touch(File.join(@default_password_dir, 'my.last.name'))
        expected_output = <<EOM
production Names:
\t10.0.1.2
\tmy.last.name
\tproduction_name
\tsalt.and.pepper

EOM
        expect { @passgen.run(['-l']) }.to output(expected_output).to_stdout
      end

      it 'lists available names for specified environment' do
        password_dir = File.join(@password_env_dir, 'env1', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(password_dir)
        FileUtils.touch(File.join(password_dir, 'env1_name1'))
        expected_output = <<EOM
env1 Names:
\tenv1_name1

EOM
        expect { @passgen.run(['-l', '-e', 'env1']) }.to output(expected_output).to_stdout
      end

      it 'fails when password directory does not exist' do
        FileUtils.rm_rf(@default_password_dir)
        expect { @passgen.run(['-l']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' does not exist")
      end

      it 'fails when password directory is not a directory' do
        FileUtils.rm_rf(@default_password_dir)
        FileUtils.touch(@default_password_dir)
        expect { @passgen.run(['-l']) }.to raise_error(
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
        expect { @passgen.run(['--name', 'production_name2,production_name3']) }.to output(expected_output).to_stdout
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
        expect { @passgen.run(['-e', 'env1', '-n', 'env1_name1']) }.to output(expected_output).to_stdout
      end

      it 'fails when no names specified' do
        expect { @passgen.run(['-n']) }.to raise_error(OptionParser::MissingArgument)
      end

      it 'fails when invalid name specified' do
        expect { @passgen.run(['-n', 'oops']) }.to raise_error(
          OptionParser::ParseError,
          /Invalid name 'oops' selected.\n\nValid names: production_name1, production_name2, production_name3/)
      end

      it 'fails when password directory does not exist' do
        FileUtils.rm_rf(@default_password_dir)
        expect { @passgen.run(['-n', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' does not exist")
      end

      it 'fails when password directory is not a directory' do
        FileUtils.rm_rf(@default_password_dir)
        FileUtils.touch(@default_password_dir)
        expect { @passgen.run(['-n', 'production_name1']) }.to raise_error(
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
        @name1_salt_file = File.join(@default_password_dir, 'production_name1.salt')
        File.open(@name1_salt_file, 'w') { |file| file.puts 'production_name1_salt' }
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
        @name4_salt_file = File.join(@env1_password_dir, 'env1_name4.salt')
        File.open(@name4_salt_file, 'w') { |file| file.puts "env1_name4_salt" }
        @name4_backup_file = File.join(@env1_password_dir, 'env1_name4.last')
        File.open(@name4_backup_file, 'w') { |file| file.puts "env1_name4_backup_password" }
      end

      context 'with default environment' do
        context 'with backups' do
          let(:expected_file_info) do {
              @name1_file                => 'first_new_password',
              @name1_backup_file         => 'production_name1_password',
              @name1_salt_file + '.last' => 'production_name1_salt',
              @name2_file                => 'second_new_password',
              @name2_file + '.last'      => 'production_name2_password',
              @name3_file                => 'production_name3_password',       # unchanged
              @name3_backup_file         => 'production_name3_backup_password' # unchanged
            }
          end

          it 'updates password file and backs up old files per prompt' do
            allow(@passgen).to receive(:get_password).and_return(
              'first_new_password', 'second_new_password')
            allow(@passgen).to receive(:yes_or_no).and_return(true)
            expected_output = <<EOM
production Name: production_name1

production Name: production_name2

EOM
            validate_set_and_backup(@passgen, ['-s', 'production_name1,production_name2' ],
              expected_output, expected_file_info)

            expect(File.exist?(@name1_salt_file)).to be false
          end

          it 'updates password file and backs up old files per --backup option' do
            allow(@passgen).to receive(:get_password).and_return(
              'first_new_password', 'second_new_password')
            expected_output = <<EOM
production Name: production_name1

production Name: production_name2

EOM
            validate_set_and_backup(@passgen, ['--backup', '-s', 'production_name1,production_name2' ],
              expected_output, expected_file_info)

            expect(File.exist?(@name1_salt_file)).to be false
          end
        end

        context 'without backups' do
          let(:expected_file_info) do {
              @name1_file        => 'first_new_password',
              @name1_backup_file => 'production_name1_backup_password', # unchanged
              @name2_file        => 'second_new_password',
              @name3_file        => 'production_name3_password',        # unchanged
              @name3_backup_file => 'production_name3_backup_password'  # unchanged
            }
          end

          it 'updates password file and does not back up old files per prompt' do
            allow(@passgen).to receive(:get_password).and_return(
              'first_new_password', 'second_new_password')
            allow(@passgen).to receive(:yes_or_no).and_return(true)
            allow(@passgen).to receive(:yes_or_no).and_return(false)

            # not mocking query output
            expected_output = <<EOM
production Name: production_name1

production Name: production_name2

EOM
            validate_set_and_backup(@passgen, ['-s', 'production_name1,production_name2' ],
              expected_output, expected_file_info)

            expect(File.exist?(@name1_salt_file)).to be false
            expect(File.exist?(@name1_salt_file + '.last')).to be false
            expect(File.exist?(@name2_file + '.last')).to eq false
          end

          it 'updates password file and does not back up old files per --no-backup option' do
            allow(@passgen).to receive(:get_password).and_return(
              'first_new_password', 'second_new_password')
            expected_output = <<EOM
production Name: production_name1

production Name: production_name2

EOM
            validate_set_and_backup(@passgen, ['--no-backup', '-s', 'production_name1,production_name2' ],
              expected_output, expected_file_info)

            expect(File.exist?(@name1_salt_file)).to be false
            expect(File.exist?(@name1_salt_file + '.last')).to be false
            expect(File.exist?(@name2_file + '.last')).to eq false
          end
        end

        it 'creates password file for new name' do
          allow(@passgen).to receive(:get_password).and_return('new_password')
          expected_output = <<EOM
production Name: new_name

EOM
          expect { @passgen.run(['--backup', '-s', 'new_name']) }.to output(
            expected_output).to_stdout
          new_password_file = File.join(@default_password_dir, 'new_name')
          expect( File.exist?(new_password_file) ).to eq true
          expect( File.exist?(new_password_file + '.salt') ).to eq false
          expect( File.exist?(new_password_file + '.last') ).to eq false
          expect( IO.read(new_password_file).chomp ).to eq 'new_password'
        end

        it 'allows multiple backups' do
          allow(@passgen).to receive(:get_password).and_return('new_password')
          @passgen.run(['--backup', '-s', 'production_name1'])
          expect { @passgen.run(['--backup', '-s', 'production_name1']) }.not_to raise_error
          expect { @passgen.run(['--backup', '-s', 'production_name1']) }.not_to raise_error
       end
      end

      context 'specified environment' do
        context 'with backups' do
          let(:expected_file_info) do {
              @name4_file                => 'new_password',
              @name4_salt_file + '.last' => 'env1_name4_salt',
              @name4_backup_file         => 'env1_name4_password'
            }
          end

          it 'updates password file and backs up old files per prompt' do
            allow(@passgen).to receive(:get_password).and_return('new_password')
            allow(@passgen).to receive(:yes_or_no).and_return(true)
            # not mocking query output
            expected_output = <<EOM
env1 Name: env1_name4

EOM
            validate_set_and_backup(@passgen, ['-e', 'env1', '-s', 'env1_name4'],
              expected_output, expected_file_info)

            expect(File.exist?(@name4_salt_file)).to be false
          end

          it 'updates password file and backs up old files per --backup option' do
            allow(@passgen).to receive(:get_password).and_return('new_password')
            expected_output = <<EOM
env1 Name: env1_name4

EOM
            validate_set_and_backup(@passgen, ['-e', 'env1', '--backup', '-s', 'env1_name4' ],
              expected_output, expected_file_info)

            expect(File.exist?(@name4_salt_file)).to be false
          end
        end

        context 'without backups' do
          let(:expected_file_info) do {
              @name4_file                => 'new_password',
              @name4_backup_file         => 'env1_name4_backup_password' # unchanged
            }
          end

          it 'updates password file and does not back up old files per prompt' do
            allow(@passgen).to receive(:get_password).and_return('new_password')
            allow(@passgen).to receive(:yes_or_no).and_return(false)
            # not mocking query output
            expected_output = <<EOM
env1 Name: env1_name4

EOM
            validate_set_and_backup(@passgen, ['-e', 'env1', '-s', 'env1_name4' ],
              expected_output, expected_file_info)

            expect(File.exist?(@name4_salt_file)).to eq false
            expect(File.exist?(@name4_salt_file + '.last')).to eq false
          end

          it 'updates password file and does not back up old files per --no-backup option' do
            allow(@passgen).to receive(:get_password).and_return('new_password')
            expected_output = <<EOM
env1 Name: env1_name4

EOM
            validate_set_and_backup(@passgen, ['-e', 'env1', '--no-backup', '-s', 'env1_name4' ],
              expected_output, expected_file_info)

            expect(File.exist?(@name4_salt_file)).to eq false
            expect(File.exist?(@name4_salt_file + '.last')).to eq false
          end
        end

        it 'creates password file for new name' do
          allow(@passgen).to receive(:get_password).and_return('new_password')
          expected_output = <<EOM
env1 Name: new_name

EOM
          expect { @passgen.run(['-e', 'env1', '--backup', '-s', 'new_name']) }.to output(
            expected_output).to_stdout
          new_password_file = File.join(@env1_password_dir, 'new_name')
          expect( File.exist?(new_password_file) ).to eq true
          expect( File.stat(new_password_file).mode & 0777 ).to eq 0640
          expect( File.exist?(new_password_file + '.last') ).to eq false
          expect( IO.read(new_password_file).chomp ).to eq 'new_password'
        end
      end

      it 'fails when no names specified' do
        expect { @passgen.run(['-s']) }.to raise_error(OptionParser::MissingArgument)
      end

      it 'fails when password directory does not exist' do
        FileUtils.rm_rf(@default_password_dir)
        expect { @passgen.run(['-s', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' does not exist")
      end

      it 'fails when password directory is not a directory' do
        FileUtils.rm_rf(@default_password_dir)
        FileUtils.touch(@default_password_dir)
        expect { @passgen.run(['-s', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' is not a directory")
      end
    end

    describe '--remove option' do
      before :each do
        @default_password_dir = File.join(@password_env_dir, 'production', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(@default_password_dir)

        @name1_file = File.join(@default_password_dir, 'production_name1')
        File.open(@name1_file, 'w') { |file| file.puts 'production_name1_password' }
        @name1_salt_file = File.join(@default_password_dir, 'production_name1.salt')
        File.open(@name1_salt_file, 'w') { |file| file.puts 'production_name1_salt' }
        @name1_backup_file = File.join(@default_password_dir, 'production_name1.last')
        File.open(@name1_backup_file, 'w') { |file| file.puts 'production_name1_backup_password' }

        @name2_file = File.join(@default_password_dir, 'production_name2')
        File.open(@name2_file, 'w') { |file| file.puts 'production_name2_password' }

        @name3_file = File.join(@default_password_dir, 'production_name3')
        File.open(@name3_file, 'w') { |file| file.puts 'production_name3_password' }
        @name3_backup_file = File.join(@default_password_dir, 'production_name3.last')
        File.open(@name3_backup_file, 'w') { |file| file.puts 'production_name3_backup_password' }

        @env1_password_dir = File.join(@password_env_dir, 'env1', 'simp_autofiles', 'gen_passwd')
        FileUtils.mkdir_p(@env1_password_dir)
        @name4_file = File.join(@env1_password_dir, 'env1_name4')
        File.open(@name4_file, 'w') { |file| file.puts 'env1_name4_password' }
        @name4_salt_file = File.join(@env1_password_dir, 'env1_name4.salt')
        File.open(@name4_salt_file, 'w') { |file| file.puts 'env1_name4_salt' }
        @name4_backup_file = File.join(@env1_password_dir, 'env1_name4.last')
        File.open(@name4_backup_file, 'w') { |file| file.puts 'env1_name4_backup_password' }
      end

      context 'with default environment' do
        it 'removes password, backup, and salt files when prompt returns yes' do
          allow(@passgen).to receive(:yes_or_no).and_return(true)
          # not mocking query output
          expected_output = <<EOM
#{@name1_file} deleted
#{@name1_salt_file} deleted
#{@name1_backup_file} deleted

#{@name2_file} deleted

EOM
          expect { @passgen.run(['-r',
            'production_name1,production_name2' ]) }.to output(expected_output).to_stdout

          expect(File.exist?(@name1_file)).to eq false
          expect(File.exist?(@name1_salt_file)).to eq false
          expect(File.exist?(@name1_backup_file)).to eq false
          expect(File.exist?(@name2_file)).to eq false
          expect(File.exist?(@name3_file)).to eq true
          expect(File.exist?(@name3_backup_file)).to eq true
        end

        it 'does not remove password, backup and salt files when prompt returns no' do
          allow(@passgen).to receive(:yes_or_no).and_return(false)
          # not mocking query output
          expected_output = "\n\n"
          expect { @passgen.run(['-r',
            'production_name1,production_name2' ]) }.to output(expected_output).to_stdout

          expect(File.exist?(@name1_file)).to eq true
          expect(File.exist?(@name1_salt_file)).to eq true
          expect(File.exist?(@name1_backup_file)).to eq true
          expect(File.exist?(@name2_file)).to eq true
          expect(File.exist?(@name3_file)).to eq true
          expect(File.exist?(@name3_backup_file)).to eq true
        end

        it 'removes password, backup, and salt files, without prompting with --force-remove option' do
          expected_output = <<EOM
#{@name1_file} deleted
#{@name1_salt_file} deleted
#{@name1_backup_file} deleted

#{@name2_file} deleted

EOM
          expect { @passgen.run(['-r', 'production_name1,production_name2',
            '--force-remove']) }.to output(expected_output).to_stdout

          expect(File.exist?(@name1_file)).to eq false
          expect(File.exist?(@name1_salt_file)).to eq false
          expect(File.exist?(@name1_backup_file)).to eq false
          expect(File.exist?(@name2_file)).to eq false
          expect(File.exist?(@name3_file)).to eq true
          expect(File.exist?(@name3_backup_file)).to eq true
        end
      end

      context 'specified environment' do
        it 'removes password, backup, and salt files, per prompt' do
          allow(@passgen).to receive(:yes_or_no).and_return(true)
          # not mocking query output
          expected_output = <<EOM
#{@name4_file} deleted
#{@name4_salt_file} deleted
#{@name4_backup_file} deleted

EOM
          expect { @passgen.run(['-e', 'env1', '-r',
            'env1_name4']) }.to output(expected_output).to_stdout

          expect(File.exist?(@name4_file)).to eq false
          expect(File.exist?(@name4_salt_file)).to eq false
          expect(File.exist?(@name4_backup_file)).to eq false
        end

        it 'does not remove password files, including backup files, per prompt' do
          allow(@passgen).to receive(:yes_or_no).and_return(false)
          # not mocking query output
          expected_output = "\n"
          expect { @passgen.run(['-e', 'env1', '-r',
            'env1_name4']) }.to output(expected_output).to_stdout

          expect(File.exist?(@name4_file)).to eq true
          expect(File.exist?(@name4_salt_file)).to eq true
          expect(File.exist?(@name4_backup_file)).to eq true
        end

        it 'removes password files, including backup files, without prompting with --force-remove option' do
          expected_output = <<EOM
#{@name4_file} deleted
#{@name4_salt_file} deleted
#{@name4_backup_file} deleted

EOM
          expect { @passgen.run(['-e', 'env1', '-r', 'env1_name4',
            '--force-remove']) }.to output(expected_output).to_stdout

          expect(File.exist?(@name4_file)).to eq false
          expect(File.exist?(@name4_salt_file)).to eq false
          expect(File.exist?(@name4_backup_file)).to eq false
        end
      end

      it 'fails when no names specified' do
        expect { @passgen.run(['-r']) }.to raise_error(OptionParser::MissingArgument)
      end

      it 'fails when invalid names specified' do
        expect { @passgen.run(['-r', 'production_name1,oops,production_name2']) }.to raise_error(
          OptionParser::ParseError,
          /Invalid name 'oops' selected.\n\nValid names: production_name1, production_name2/)
      end

      it 'fails when password directory does not exist' do
        FileUtils.rm_rf(@default_password_dir)
        expect { @passgen.run(['-r', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' does not exist")
      end

      it 'fails when password directory is not a directory' do
        FileUtils.rm_rf(@default_password_dir)
        FileUtils.touch(@default_password_dir)
        expect { @passgen.run(['-r', 'production_name1']) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Password directory '#{@default_password_dir}' is not a directory")
      end
    end

    describe 'option validation' do
      it 'requires operation option to be specified' do
        expect { @passgen.run([]) }.to raise_error(OptionParser::ParseError,
          /The SIMP Passgen Tool requires at least one option/)

        expect { @passgen.run(['-e', 'production']) }.to raise_error(OptionParser::ParseError,
          /No password operation specified./)
      end
    end
  end
end
