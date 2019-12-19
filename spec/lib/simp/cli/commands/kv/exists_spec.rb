require 'simp/cli/commands/kv'
require 'simp/cli/commands/kv/exists'

require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Commands::Kv::Exists do
  before :each do
    # expose HighLine input and output for test validation
    @input = StringIO.new
    @output = StringIO.new
    @prev_terminal = $terminal
    $terminal = HighLine.new(@input, @output)

    @kv = Simp::Cli::Commands::Kv::Exists.new
  end

  after :each do
    @input.close
    @output.close
    $terminal = @prev_terminal
  end

  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Kv::Exists.description}/
      expect{ @kv.run(['-h']) }.to output(expected_stdout_regex).to_stdout
    end
  end

  describe '#run' do
    let(:entities) { [ 'key1', 'key2', 'folder1', 'folder2' ] }
    let(:entities_arg) { entities.join(',') }
    let(:default_backend) { 'default' }
    let(:default_env) { 'production' }

    context 'default options' do
      it 'checks folders/keys for default env in default backend' do
        mock_ckr = object_double('Mock Existence Checker', { :exists => nil })
        expect(mock_ckr).to receive(:exists).with('key1',false).and_return(false)
        expect(mock_ckr).to receive(:exists).with('key2',false).and_return(true)
        expect(mock_ckr).to receive(:exists).with('folder1',false).and_return(true)
        expect(mock_ckr).to receive(:exists).with('folder2',false).and_return(false)

        allow(Simp::Cli::Kv::EntityChecker).to receive(:new)
          .with(default_env, default_backend).and_return(mock_ckr)

        expected_output = <<~EOM
          Processing 'key1' in 'production' environment... done.
          Processing 'key2' in 'production' environment... done.
          Processing 'folder1' in 'production' environment... done.
          Processing 'folder2' in 'production' environment... done.

          {
            "key1": "absent",
            "key2": "present",
            "folder1": "present",
            "folder2": "absent"
          }
        EOM

        @kv.run([ entities_arg ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'checks as many folders/keys as possible and fails with list of '\
         'folder/key failures' do
        mock_ckr = object_double('Mock Existence Checker', { :exists => nil })
        expect(mock_ckr).to receive(:exists).with('key1',false).and_return(true)
        expect(mock_ckr).to receive(:exists).with('folder2',false).and_return(false)
        expect(mock_ckr).to receive(:exists).with('key2',false).and_raise(
          Simp::Cli::ProcessingError, 'Check failed: server busy')

        expect(mock_ckr).to receive(:exists).with('folder1',false).and_raise(
          Simp::Cli::ProcessingError, 'Check failed: connection timed out')

        allow(Simp::Cli::Kv::EntityChecker).to receive(:new)
          .with(default_env, default_backend).and_return(mock_ckr)

        expected_stdout = <<~EOM
          Processing 'key1' in 'production' environment... done.
          Processing 'key2' in 'production' environment... done.
          Processing 'folder1' in 'production' environment... done.
          Processing 'folder2' in 'production' environment... done.

          {
            "key1": "present",
            "folder2": "absent"
          }
        EOM

        expected_err_msg = <<~EOM
          Failed to check existence of 2 out of 4 folders/keys:
            'key2': Check failed: server busy
            'folder1': Check failed: connection timed out
        EOM

        expect { @kv.run([ entities_arg ]) }
          .to raise_error( Simp::Cli::ProcessingError,
          expected_err_msg.strip)

        expect( @output.string ).to eq(expected_stdout)
      end
    end

    context 'custom options' do
      let(:key1_status_json) do
        <<~EOM
          {
            "key1": "present"
          }
        EOM
      end

      before :each do
        @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
        @outfile = File.join(@tmp_dir, 'status.json')
      end

      after :each do
        FileUtils.remove_entry_secure @tmp_dir
      end

      it 'writes check results to file when --outfile' do
        mock_ckr = object_double('Mock Existence Checker', { :exists => nil })
        expect(mock_ckr).to receive(:exists).with('key1',false).and_return(true)
        allow(Simp::Cli::Kv::EntityChecker).to receive(:new)
          .with(default_env, default_backend).and_return(mock_ckr)

        expected_output = <<~EOM
          Processing 'key1' in 'production' environment... done.

          Output for folder/key existence check written to #{@outfile}
        EOM

        @kv.run([ 'key1', '--outfile', @outfile ])
        expect( @output.string ).to eq(expected_output)
        expect( File.read(@outfile) ).to eq(key1_status_json)
      end

      it 'does not write check results to file when --outfile and all queries fail' do
        mock_ckr = object_double('Mock Existence Checker', { :exists => nil })
        expect(mock_ckr).to receive(:exists).with('key1',false).and_raise(
          Simp::Cli::ProcessingError, 'Check failed: server busy')

        allow(Simp::Cli::Kv::EntityChecker).to receive(:new)
          .with(default_env, default_backend).and_return(mock_ckr)

        expected_output = <<~EOM
          Processing 'key1' in 'production' environment... done.

        EOM

        expect { @kv.run([ 'key1', '--outfile', @outfile ]) }
          .to raise_error( Simp::Cli::ProcessingError,
          /Failed to check existence/)

        expect( File.exist?(@outfile) ).to be(false)
      end

      it 'checks for global folders/keys when --global' do
        mock_ckr = object_double('Mock Existence Checker', { :exists => nil })
        expect(mock_ckr).to receive(:exists).with('key1',true).and_return(true)

        allow(Simp::Cli::Kv::EntityChecker).to receive(:new)
          .with(default_env, default_backend).and_return(mock_ckr)

        expected_output = <<~EOM
          Processing global 'key1'... done.

          #{key1_status_json.strip}
        EOM

        @kv.run([ 'key1', '--global' ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'checks for folders/keys for backend specified by --backend' do
        mock_ckr = object_double('Mock Existence Checker', { :exists => nil })
        expect(mock_ckr).to receive(:exists).with('key1',false).and_return(true)

        backend = 'custom_backend'
        allow(Simp::Cli::Kv::EntityChecker).to receive(:new)
          .with(default_env, backend).and_return(mock_ckr)

        expected_output = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.

          #{key1_status_json.strip}
        EOM

        @kv.run([ 'key1', '--backend', backend ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'checks for folders/keys for environment specified by --environment' do
        mock_ckr = object_double('Mock Existence Checker', { :exists => nil })
        expect(mock_ckr).to receive(:exists).with('key1',false).and_return(true)

        env = 'dev'
        allow(Simp::Cli::Kv::EntityChecker).to receive(:new)
          .with(env, default_backend).and_return(mock_ckr)

        expected_output = <<~EOM
          Processing 'key1' in '#{env}' environment... done.

          #{key1_status_json.strip}
        EOM

        @kv.run([ 'key1', '--environment', env ])
        expect( @output.string ).to eq(expected_output)
      end
    end

    context 'option validation' do
      it 'fails if no folders/keys are specified' do
        expect { @kv.run([]) }.to raise_error(
          Simp::Cli::ProcessingError,
          'Folders/keys to check are missing from command line')
      end
    end
  end
end
