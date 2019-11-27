require 'simp/cli/passgen/utils'
require 'spec_helper'
require 'test_utils/mock_logger'

describe Simp::Cli::Passgen::Utils do
  describe '.get_password' do
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

    let(:password1) { 'A=V3ry=Go0d=P@ssw0r!' }

    it 'accepts a valid password when entered twice' do
      @input << "#{password1}\n"
      @input << "#{password1}\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.get_password ).to eq password1

      expected = <<EOM
> Enter password: ********************
> Confirm password: ********************
EOM
      expect(@output.string.uncolor).to eq expected
    end

    it 're-prompts when the entered password fails validation' do
      @input << "short\n"
      @input << "#{password1}\n"
      @input << "#{password1}\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.get_password ).to eq password1

      expected = <<EOM
> Enter password: *****
> Enter password: ********************
> Confirm password: ********************
EOM
      expect(@output.string.uncolor).to eq expected
    end

    it 'starts over when the confirm password does not match entered password' do
      @input << "#{password1}\n"
      @input << "bad confirm\n"
      @input << "#{password1}\n"
      @input << "#{password1}\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.get_password ).to eq password1

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
      expect{ Simp::Cli::Passgen::Utils.get_password }
        .to raise_error(Simp::Cli::ProcessingError)
    end

    it 'accepts an invalid password when validation disabled' do
      simple_password = 'password'
      @input << "#{simple_password}\n"
      @input << "#{simple_password}\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.get_password(5, false) )
        .to eq simple_password
    end
  end

  describe '.yes_or_no' do
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

    it "when default_yes=true, prompts, accepts default of 'yes' and " +
       'returns true' do

      @input << "\n"
      @input.rewind

      expect( Simp::Cli::Passgen::Utils.yes_or_no('Remove backups', true) )
        .to eq true

      expect( @output.string.uncolor ).to eq '> Remove backups: |yes| '
    end

    it "when default_yes=false, prompts, accepts default of 'no' and " +
       'returns false' do

      @input << "\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.yes_or_no('Remove backups', false) )
        .to eq false

      expect( @output.string.uncolor ).to eq '> Remove backups: |no| '
    end

    ['yes', 'YES', 'y', 'Y'].each do |response|
      it "accepts '#{response}' and returns true" do
        @input << "#{response}\n"
        @input.rewind
        expect( Simp::Cli::Passgen::Utils.yes_or_no('Remove backups', false) )
          .to eq true
      end
    end

    ['no', 'NO', 'n', 'N'].each do |response|
      it "accepts '#{response}' and returns false" do
        @input << "#{response}\n"
        @input.rewind
        expect( Simp::Cli::Passgen::Utils.yes_or_no('Remove backups', false) )
          .to eq false
      end
    end

    it 're-prompts user when user does not enter a string that begins ' +
       'with Y, y, N, or n' do

      @input << "oops\n"
      @input << "I\n"
      @input << "can't\n"
      @input << "type!\n"
      @input << "yes\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.yes_or_no('Remove backups', false) )
        .to eq true
    end

  end

  describe '.apply_manifest' do
    let(:manifest) { "simplib::passgen::remove('name')" }
    let(:cmd_prefix) {
      "sg puppet -c 'puppet apply --color=false" +
        " --environment=production --vardir=/server/var/dir"
    }

    before :each do
      puppet_info = {
        :config => {
          'user'   => 'puppet',
          'group'  => 'puppet',
          'vardir' => '/server/var/dir'
        }
      }

      allow(Simp::Cli::Utils).to receive(:puppet_info).and_return(puppet_info)
    end

    context 'without logger' do
      it 'returns apply result when apply succeeds' do
        cmd_regex = /#{Regexp.escape(cmd_prefix)} .*passgen.pp/
        result = {
          :status => true,
          :stdout => 'Puppet Notice messages',
          :stderr => 'Puppet Warning messages'
        }

        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(result)

        expect( Simp::Cli::Passgen::Utils.apply_manifest(manifest) )
          .to eq(result)
      end

      it 'returns apply result when apply fails and :fail option unspecified' do
        cmd_regex = /#{Regexp.escape(cmd_prefix)} .*passgen.pp/
        result = {
          :status => false,
          :stdout => 'Puppet Notice messages',
          :stderr => 'Puppet Warning and Error messages'
        }
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(result)

        expect( Simp::Cli::Passgen::Utils.apply_manifest(manifest) )
          .to eq(result)
      end

      it 'returns apply result when apply fails and :fail option is false' do
        cmd_regex = /#{Regexp.escape(cmd_prefix)} .*passgen.pp/
        result = {
          :status => false,
          :stdout => 'Puppet Notice messages',
          :stderr => 'Puppet Warning and Error messages'
        }
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(result)

        opts = { :fail => false }
        expect( Simp::Cli::Passgen::Utils.apply_manifest(manifest, opts) )
          .to eq(result)
      end

      it 'fails when apply fails and :fail option is true' do
        cmd_regex = /#{Regexp.escape(cmd_prefix)} .*passgen.pp/
        result = {
          :status => false,
          :stdout => 'Puppet Notice messages',
          :stderr => 'Puppet Warning and Error messages'
        }
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(result)

        opts = { :fail => true }
        first = "puppet apply failed:\n>>> Command:"
        last =<<-EOM

>>> Manifest:
#{Regexp.escape(manifest)}
>>> stderr:
#{result[:stderr]}
        EOM
        last.chomp!

        expected_regex = /#{first} #{Regexp.escape(cmd_prefix)} .*passgen.pp'#{last}/m
        expect{ Simp::Cli::Passgen::Utils.apply_manifest(manifest, opts) }
          .to raise_error(Simp::Cli::ProcessingError, expected_regex)
      end

      it 'uses opts :env and :title when specified' do
        cmd_prefix_dev = cmd_prefix.gsub('production', 'dev')
        cmd_regex = /#{Regexp.escape(cmd_prefix_dev)} .*passgen.pp/
        result = {
          :status => false,
          :stdout => 'Puppet Notice messages',
          :stderr => 'Puppet Warning and Error messages'
        }

        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(result)

        opts = { :env => 'dev', :title => 'password remove', :fail => true }
        first = "password remove failed:\n>>> Command:"
        last = <<-EOM

>>> Manifest:
#{Regexp.escape(manifest)}
>>> stderr:
#{result[:stderr]}
        EOM
        last.chomp!

        expected_regex = /#{first} #{Regexp.escape(cmd_prefix_dev)} .*passgen.pp'#{last}/m
        expect{ Simp::Cli::Passgen::Utils.apply_manifest(manifest, opts) }
          .to raise_error(Simp::Cli::ProcessingError, expected_regex)
      end
    end

    context 'with logger' do
      it 'returns apply result when apply succeeds' do
        cmd_regex = /#{Regexp.escape(cmd_prefix)} .*passgen.pp/
        result = {
          :status => true,
          :stdout => 'Puppet Notice messages',
          :stderr => 'Puppet Warning messages'
        }

        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(result)

        logger = TestUtils::MockLogger.new
        expect( Simp::Cli::Passgen::Utils.apply_manifest(manifest, {}, logger) )
          .to eq(result)

        expected = "Creating manifest file for puppet apply with content:\n" +
          manifest

        expect( logger.messages[:debug][0][0] ).to eq(expected)

        expected_regex = /Executing: #{Regexp.escape(cmd_prefix)} .*passgen.pp/
        expect( logger.messages[:debug][1][0] ).to match(expected_regex)

        expected = ">>> stdout:\n#{result[:stdout]}"
        expect( logger.messages[:debug][2][0] ).to eq(expected)

        expected = ">>> stderr:\n#{result[:stderr]}"
        expect( logger.messages[:debug][3][0] ).to eq(expected)
      end

      it 'uses opts :env and :title when specified' do
        cmd_prefix_dev = cmd_prefix.gsub('production', 'dev')
        cmd_regex = /#{Regexp.escape(cmd_prefix_dev)} .*passgen.pp/
        result = {
          :status => false,
          :stdout => 'Puppet Notice messages',
          :stderr => 'Puppet Warning and Error messages'
        }

        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(result)

        opts = { :env => 'dev', :title => 'password remove', :fail => true }
        logger = TestUtils::MockLogger.new
        first = "password remove failed:\n>>> Command:"
        last =<<-EOM

>>> Manifest:
#{Regexp.escape(manifest)}
>>> stderr:
#{result[:stderr]}
        EOM
        last.chomp!

        expected_regex = /#{first} #{Regexp.escape(cmd_prefix_dev)} .*passgen.pp'#{last}/m
        expect{
          Simp::Cli::Passgen::Utils.apply_manifest(manifest, opts, logger) }
          .to raise_error(Simp::Cli::ProcessingError, expected_regex)

        expected = "Creating manifest file for password remove with content:\n" +
          manifest

        expect( logger.messages[:debug][0][0] ).to eq(expected)

        expected_regex = /Executing: #{Regexp.escape(cmd_prefix_dev)} .*passgen.pp/
        expect( logger.messages[:debug][1][0] ).to match(expected_regex)

        expected = ">>> stdout:\n#{result[:stdout]}"
        expect( logger.messages[:debug][2][0] ).to eq(expected)

        expected = ">>> stderr:\n#{result[:stderr]}"
        expect( logger.messages[:debug][3][0] ).to eq(expected)
      end
    end
  end

  describe '.load_yaml' do
    let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
    context 'without logger' do
      it 'returns Hash for valid YAML file' do
        file = File.join(files_dir, 'good.yaml')
        yaml =  Simp::Cli::Passgen::Utils.load_yaml(file, 'password info')

        expected = {
          'value' => { 'password' => 'password1', 'salt' => 'salt1' }
        }

        expect( yaml ).to eq(expected)
      end

      it 'fails when the file does not exist' do
        expect{ Simp::Cli::Passgen::Utils.load_yaml('oops', 'password list') }
        .to raise_error(Simp::Cli::ProcessingError,
         /Failed to load password list YAML:\n<<< Error: No such file or directory/m)
      end

      it 'fails when YAML file cannot be parsed' do
        file = File.join(files_dir, 'bad.yaml')
        expected_regex = /Failed to load password info YAML:\n<<< YAML Content:\n#{File.read(file)}\n<<< Error: /m
        expect{ Simp::Cli::Passgen::Utils.load_yaml(file, 'password info') }
          .to raise_error(Simp::Cli::ProcessingError, expected_regex)
      end
    end

    context 'with logger' do
      it 'returns Hash for valid YAML file' do
        file = File.join(files_dir, 'good.yaml')
        logger = TestUtils::MockLogger.new
        yaml =  Simp::Cli::Passgen::Utils.load_yaml(file, 'info', logger)

        expected = {
          'value' => { 'password' => 'password1', 'salt' => 'salt1' }
        }

        expect( yaml ).to eq(expected)
        expected_debug = [
          [ 'Loading info YAML from file' ],
          [ "Content:\n#{File.read(file)}" ]
        ]
        expect( logger.messages[:debug] ).to eq(expected_debug)
      end

      it 'fails when the file does not exist' do
        logger = TestUtils::MockLogger.new
        expect{
          Simp::Cli::Passgen::Utils.load_yaml('oops', 'password list', logger) }
          .to raise_error(Simp::Cli::ProcessingError,
           /Failed to load password list YAML:\n<<< Error: No such file or directory/m)

        expected_debug = [ [ 'Loading password list YAML from file' ] ]
        expect( logger.messages[:debug] ).to eq(expected_debug)
      end

      it 'fails when YAML file cannot be parsed' do
        file = File.join(files_dir, 'bad.yaml')
        logger = TestUtils::MockLogger.new
        expected_regex = /Failed to load password info YAML:\n<<< YAML Content:\n#{File.read(file)}\n<<< Error: /m
        expect{
          Simp::Cli::Passgen::Utils.load_yaml(file, 'password info', logger) }
          .to raise_error(Simp::Cli::ProcessingError, expected_regex)

        expected_debug = [
          [ 'Loading password info YAML from file' ],
          [ "Content:\n#{File.read(file)}" ]
        ]
        expect( logger.messages[:debug] ).to eq(expected_debug)
      end
    end
  end
end
