require 'simp/cli/apply_utils'
require 'spec_helper'
require 'test_utils/mock_logger'

describe Simp::Cli::ApplyUtils do

  describe '.apply_manifest_with_spawn' do
    let(:manifest) { "simplib::passgen::remove('name')" }
    let(:manifest_with_fail_message) {
      <<~EOM
        if empty(simplib::passgen::get('name')  {
          fail("'name' does not exist")
        } else {
          simplib::passgen::remove('name')
        }
      EOM
    }

    let(:apply_cmd_prefix) { 'puppet apply --color=false --environment=production' }
    let(:sg_cmd_prefix) {
      "sg puppet -c 'puppet apply --color=false --environment=dev "\
      "--vardir=/server/var/dir"
    }

    let(:custom_opts) do
      {
        :env           => 'dev',
        :group         => 'puppet',
        :fail          => true,
        :fail_filter   => "'name' does not exist",
        :puppet_config => { 'vardir' => '/server/var/dir' },
        :title         => 'my title'
      }
    end

    let(:success_result) do
      {
        :status => true,
        :stdout => "Notice: Puppet notice message\nInfo: Puppet info message",
        :stderr => 'Warning: Puppet warning message'
      }
    end

    let(:fail_result) do
      {
        :status => false,
        :stdout => 'Puppet notice message',
        :stderr => [
          'Warning: Puppet warning message',
          "Error: 'name' does not exist",
          'Error: other Puppet error message'
        ].join("\n")
      }
    end

    context 'without logger' do
      it 'returns apply result when apply from default options succeeds' do
        cmd_regex = /^#{Regexp.escape(apply_cmd_prefix)} .*apply_manifest.pp$/

        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(success_result)

        expect( Simp::Cli::ApplyUtils.apply_manifest_with_spawn(manifest) )
          .to eq(success_result)
      end

      it 'returns apply result when apply with custom options succeeds' do
        cmd_regex = /^#{Regexp.escape(sg_cmd_prefix)} .*apply_manifest.pp'/
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(success_result)

        expect( Simp::Cli::ApplyUtils.apply_manifest_with_spawn(manifest,
          custom_opts) ).to eq(success_result)
      end

      it 'returns apply result when apply fails and :fail option is false' do
        cmd_regex = /^#{Regexp.escape(apply_cmd_prefix)} .*apply_manifest.pp$/
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(fail_result)

        opts = { :fail => false }
        expect( Simp::Cli::ApplyUtils.apply_manifest_with_spawn(manifest, opts) )
          .to eq(fail_result)
      end

      it 'fails when apply fails and :fail option is unspecified' do
        cmd_regex = /^#{Regexp.escape(apply_cmd_prefix)} .*apply_manifest.pp$/
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(fail_result)

        expected = [
          'puppet apply failed:',
          "    Error: 'name' does not exist",
          '    Error: other Puppet error message'
        ].join("\n")

        expect{ Simp::Cli::ApplyUtils.apply_manifest_with_spawn(manifest) }
          .to raise_error(Simp::Cli::ProcessingError, expected)
      end

      it 'fails with :fail_filter message when apply fails and stderr matches that message' do
        cmd_regex = /^#{Regexp.escape(sg_cmd_prefix)} .*apply_manifest.pp'/
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(fail_result)

        expect{ Simp::Cli::ApplyUtils.apply_manifest_with_spawn(
           manifest_with_fail_message, custom_opts) }
          .to raise_error(Simp::Cli::ProcessingError, custom_opts[:fail_filter])
      end

      it 'fails with standard message when apply fails and stderr does not match :fail_filter' do
        cmd_regex = /^#{Regexp.escape(sg_cmd_prefix)} .*apply_manifest.pp'/
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(fail_result)

        opts = custom_opts.dup
        opts[:fail_filter] = 'Different error message'
        expected = [
          'my title failed:',
          "    Error: 'name' does not exist",
          '    Error: other Puppet error message'
        ].join("\n")
        expect{ Simp::Cli::ApplyUtils.apply_manifest_with_spawn(
          manifest_with_fail_message, opts) }
          .to raise_error(Simp::Cli::ProcessingError, expected)
      end
    end

    context 'with logger' do
      it 'returns apply result when apply succeeds and logs' do
        cmd_regex = /^#{Regexp.escape(apply_cmd_prefix)} .*apply_manifest.pp$/
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(success_result)

        logger = TestUtils::MockLogger.new
        expect( Simp::Cli::ApplyUtils.apply_manifest_with_spawn(manifest, {}, logger) )
          .to eq(success_result)

        expected = "Creating manifest file for puppet apply with content:\n\n"\
          "#{manifest}\n"

        expect( logger.messages[:debug][0][0] ).to eq(expected)

        expected_regex = /Executing: #{Regexp.escape(apply_cmd_prefix)} .*apply_manifest.pp$/
        expect( logger.messages[:debug][1][0] ).to match(expected_regex)

        expected = ">>> stdout:\n#{success_result[:stdout]}"
        expect( logger.messages[:debug][2][0] ).to eq(expected)

        expected = ">>> stderr:\n#{success_result[:stderr]}"
        expect( logger.messages[:debug][3][0] ).to eq(expected)
      end

      it 'fails when apply fails and logs' do
        cmd_regex = /^#{Regexp.escape(sg_cmd_prefix)} .*apply_manifest.pp'/
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(cmd_regex).and_return(fail_result)

        logger = TestUtils::MockLogger.new
        expect{ Simp::Cli::ApplyUtils.apply_manifest_with_spawn(
           manifest_with_fail_message, custom_opts, logger) }
          .to raise_error(Simp::Cli::ProcessingError, custom_opts[:fail_filter])

        expected = "Creating manifest file for my title with content:\n\n"\
          "#{manifest_with_fail_message}\n"

        expect( logger.messages[:debug][0][0] ).to eq(expected)

        expected_regex = /Executing: #{Regexp.escape(sg_cmd_prefix)} .*apply_manifest.pp'$/
        expect( logger.messages[:debug][1][0] ).to match(expected_regex)

        expected = ">>> stdout:\n#{fail_result[:stdout]}"
        expect( logger.messages[:debug][2][0] ).to eq(expected)

        expected = ">>> stderr:\n#{fail_result[:stderr]}"
        expect( logger.messages[:debug][3][0] ).to eq(expected)
      end
    end
  end

  describe '.load_yaml' do
    let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
    context 'without logger' do
      it 'returns Hash for valid YAML file' do
        file = File.join(files_dir, 'good.yaml')
        yaml =  Simp::Cli::ApplyUtils.load_yaml(file, 'password info')

        expected = {
          'value' => { 'password' => 'password1', 'salt' => 'salt1' }
        }

        expect( yaml ).to eq(expected)
      end

      it 'fails when the file does not exist' do
        expect{ Simp::Cli::ApplyUtils.load_yaml('oops', 'password list') }
        .to raise_error(Simp::Cli::ProcessingError,
         /Failed to load password list YAML:\n<<< Error: No such file or directory/m)
      end

      it 'fails when YAML file cannot be parsed' do
        file = File.join(files_dir, 'bad.yaml')
        expected_regex = /Failed to load password info YAML:\n<<< YAML Content:\n#{File.read(file)}\n<<< Error: /m
        expect{ Simp::Cli::ApplyUtils.load_yaml(file, 'password info') }
          .to raise_error(Simp::Cli::ProcessingError, expected_regex)
      end
    end

    context 'with logger' do
      it 'returns Hash for valid YAML file' do
        file = File.join(files_dir, 'good.yaml')
        logger = TestUtils::MockLogger.new
        yaml =  Simp::Cli::ApplyUtils.load_yaml(file, 'info', logger)

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
          Simp::Cli::ApplyUtils.load_yaml('oops', 'password list', logger) }
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
          Simp::Cli::ApplyUtils.load_yaml(file, 'password info', logger) }
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
