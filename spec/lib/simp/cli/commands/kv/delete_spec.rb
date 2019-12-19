require 'simp/cli/commands/kv'
require 'simp/cli/commands/kv/delete'

require 'spec_helper'

describe Simp::Cli::Commands::Kv::Delete do
  before :each do
    # expose HighLine input and output for test validation
    @input = StringIO.new
    @output = StringIO.new
    @prev_terminal = $terminal
    $terminal = HighLine.new(@input, @output)

    @kv = Simp::Cli::Commands::Kv::Delete.new
  end

  after :each do
    @input.close
    @output.close
    $terminal = @prev_terminal
  end

  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Kv::Delete.description}/
      expect{ @kv.run(['-h']) }.to output(expected_stdout_regex).to_stdout
    end
  end

  describe '#run' do
    let(:keys) { [ 'key1', 'key2', 'key3', 'key4' ] }
    let(:keys_arg) { keys.join(',') }
    let(:default_backend) { 'default' }
    let(:default_env) { 'production' }

    context 'default options' do
      it 'removes keys for default env in default backend when prompt '\
         'returns yes' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_del = object_double('Mock Key Deleter', { :delete => nil })
        keys.each do |key|
          expect(mock_del).to receive(:delete).with(key,false).and_return(nil)
        end

        allow(Simp::Cli::Kv::KeyDeleter).to receive(:new)
          .with(default_env, default_backend).and_return(mock_del)

        expected_output = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.
            Removed 'key1'

          Processing 'key2' in '#{default_env}' environment... done.
            Removed 'key2'

          Processing 'key3' in '#{default_env}' environment... done.
            Removed 'key3'

          Processing 'key4' in '#{default_env}' environment... done.
            Removed 'key4'

        EOM

        @kv.run([ keys_arg ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'does not remove keys for default env in default backend when '\
         'prompt returns no' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(false)
        mock_del = object_double('Mock Key Deleter', { :delete => nil })
        allow(Simp::Cli::Kv::KeyDeleter).to receive(:new)
          .with(default_env, default_backend).and_return(mock_del)

        expected_output = <<~EOM
          Skipped 'key1' in '#{default_env}' environment

          Skipped 'key2' in '#{default_env}' environment

          Skipped 'key3' in '#{default_env}' environment

          Skipped 'key4' in '#{default_env}' environment

        EOM

        @kv.run([ keys_arg ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'removes as many keys as possible and fails with list of key '\
         'remove failures' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_del = object_double('Mock Key Deleter', { :delete => nil })
        expect(mock_del).to receive(:delete).with('key1',false).and_return(nil)
        expect(mock_del).to receive(:delete).with('key4',false).and_return(nil)
        expect(mock_del).to receive(:delete).with('key2',false).and_raise(
          Simp::Cli::ProcessingError, 'Remove failed: key not found')

        expect(mock_del).to receive(:delete).with('key3',false).and_raise(
          Simp::Cli::ProcessingError, 'Remove failed: permission denied')

        allow(Simp::Cli::Kv::KeyDeleter).to receive(:new)
          .with(default_env, default_backend).and_return(mock_del)

        expected_stdout = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.
            Removed 'key1'

          Processing 'key2' in '#{default_env}' environment... done.
            Skipped 'key2'

          Processing 'key3' in '#{default_env}' environment... done.
            Skipped 'key3'

          Processing 'key4' in '#{default_env}' environment... done.
            Removed 'key4'

        EOM

        expected_err_msg = <<~EOM
          Failed to remove 2 out of 4 keys:
            'key2': Remove failed: key not found
            'key3': Remove failed: permission denied
        EOM

        expect { @kv.run([ keys_arg ]) }
          .to raise_error( Simp::Cli::ProcessingError,
          expected_err_msg.strip)

        expect( @output.string ).to eq(expected_stdout)
      end
    end

    context 'custom options' do
      it 'removes keys without prompting when --force' do
        mock_del = object_double('Mock Key Deleter', { :delete => nil })
        expect(mock_del).to receive(:delete).with('key1',false).and_return(nil)

        allow(Simp::Cli::Kv::KeyDeleter).to receive(:new)
          .with(default_env, default_backend).and_return(mock_del)

        expected_output = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.
            Removed 'key1'

        EOM

        @kv.run([ 'key1', '--force' ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'removes global keys when --global' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_del = object_double('Mock Key Deleter', { :delete => nil })
        expect(mock_del).to receive(:delete).with('key1',true).and_return(nil)

        allow(Simp::Cli::Kv::KeyDeleter).to receive(:new)
          .with(default_env, default_backend).and_return(mock_del)

        expected_output = <<~EOM
          Processing global 'key1'... done.
            Removed 'key1'

        EOM

        @kv.run([ 'key1', '--global' ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'removes keys for backend specified by --backend' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_del = object_double('Mock Key Deleter', { :delete => nil })
        expect(mock_del).to receive(:delete).with('key1',false).and_return(nil)

        backend = 'custom_backend'
        allow(Simp::Cli::Kv::KeyDeleter).to receive(:new)
          .with(default_env, backend).and_return(mock_del)

        expected_output = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.
            Removed 'key1'

        EOM

        @kv.run([ 'key1', '--backend', backend ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'removes keys for environment specified by --environment' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_del = object_double('Mock Key Deleter', { :delete => nil })
        expect(mock_del).to receive(:delete).with('key1',false).and_return(nil)

        env = 'dev'
        allow(Simp::Cli::Kv::KeyDeleter).to receive(:new)
          .with(env, default_backend).and_return(mock_del)

        expected_output = <<~EOM
          Processing 'key1' in '#{env}' environment... done.
            Removed 'key1'

        EOM


        @kv.run([ 'key1', '--environment', env ])
        expect( @output.string ).to eq(expected_output)
      end
    end

    context 'option validation' do
      it 'fails if no keys are specified' do
        expect { @kv.run([]) }.to raise_error(
          Simp::Cli::ProcessingError,
          'Keys to remove are missing from command line')
      end
    end
  end
end
