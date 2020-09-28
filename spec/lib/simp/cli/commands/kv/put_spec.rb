require 'simp/cli/commands/kv'
require 'simp/cli/commands/kv/put'

require 'spec_helper'

describe Simp::Cli::Commands::Kv::Put do
  before :each do
    # expose HighLine input and output for test validation
    @input = StringIO.new
    @output = StringIO.new
    HighLine.default_instance = HighLine.new(@input, @output)

    @kv = Simp::Cli::Commands::Kv::Put.new
  end

  after :each do
    @input.close
    @output.close
    HighLine.default_instance = HighLine.new
  end

  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Kv::Put.description}/
      expect{ @kv.run(['-h']) }.to output(expected_stdout_regex).to_stdout
    end
  end

  describe '#run' do
    let(:files_dir) { File.join(__dir__, 'files') }
    let(:valid_file) { File.join(files_dir, 'valid.json') }
    let(:keys_json) { File.read(valid_file) }
    let(:keys) { JSON.parse(keys_json) }
    let(:default_backend) { 'default' }
    let(:default_env) { 'production' }

    context 'default options' do
      it 'sets keys from --infile for default env in default backend' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_str = object_double('Mock Key Storer', { :put => nil })
        keys.each do |key,info|
          expect(mock_str).to receive(:put)
          .with(key, info['value'],info['metadata'],info.key?('encoding'),false)
          .and_return(nil)
        end

        allow(Simp::Cli::Kv::KeyStorer).to receive(:new)
          .with(default_env, default_backend).and_return(mock_str)

        expected_output = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.
            Set 'key1'

          Processing 'key2' in '#{default_env}' environment... done.
            Set 'key2'

          Processing 'key3' in '#{default_env}' environment... done.
            Set 'key3'

          Processing 'key4' in '#{default_env}' environment... done.
            Set 'key4'

        EOM

        @kv.run([ '--infile', valid_file ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'sets keys from --json for default env in default backend' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_str = object_double('Mock Key Storer', { :put => nil })
        keys.each do |key,info|
          expect(mock_str).to receive(:put)
          .with(key, info['value'],info['metadata'],info.key?('encoding'),false)
          .and_return(nil)
        end

        allow(Simp::Cli::Kv::KeyStorer).to receive(:new)
          .with(default_env, default_backend).and_return(mock_str)

        expected_output = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.
            Set 'key1'

          Processing 'key2' in '#{default_env}' environment... done.
            Set 'key2'

          Processing 'key3' in '#{default_env}' environment... done.
            Set 'key3'

          Processing 'key4' in '#{default_env}' environment... done.
            Set 'key4'

        EOM

        @kv.run([ '--json', JSON.generate(keys) ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'does not set keys for default env in default backend when '\
         'prompt returns no' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(false)
        mock_str = object_double('Mock Key Storer', { :delete => nil })
        allow(Simp::Cli::Kv::KeyStorer).to receive(:new)
          .with(default_env, default_backend).and_return(mock_str)

        expected_output = <<~EOM
          Skipped 'key1' in '#{default_env}' environment

          Skipped 'key2' in '#{default_env}' environment

          Skipped 'key3' in '#{default_env}' environment

          Skipped 'key4' in '#{default_env}' environment

        EOM

        @kv.run([ '--infile', valid_file ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'sets as many keys as possible and fails with list of key '\
         'set failures' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_str = object_double('Mock Key Storer', { :delete => nil })
        expect(mock_str).to receive(:put)
          .with('key1',keys['key1']['value'],keys['key1']['metadata'],false,false)
          .and_return(nil)

        expect(mock_str).to receive(:put)
          .with('key4',keys['key4']['value'],keys['key4']['metadata'],false,false)
          .and_return(nil)

        expect(mock_str).to receive(:put)
          .with('key2',keys['key2']['value'],keys['key2']['metadata'],false,false)
          .and_raise(
          Simp::Cli::ProcessingError, 'Put failed: connection timed out')

        expect(mock_str).to receive(:put)
          .with('key3',keys['key3']['value'],keys['key3']['metadata'],true,false)
          .and_raise(
          Simp::Cli::ProcessingError, 'Put failed: permission denied')

        allow(Simp::Cli::Kv::KeyStorer).to receive(:new)
          .with(default_env, default_backend).and_return(mock_str)

        expected_stdout = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.
            Set 'key1'

          Processing 'key2' in '#{default_env}' environment... done.
            Skipped 'key2'

          Processing 'key3' in '#{default_env}' environment... done.
            Skipped 'key3'

          Processing 'key4' in '#{default_env}' environment... done.
            Set 'key4'

        EOM

        expected_err_msg = <<~EOM
          Failed to set 2 out of 4 keys:
            'key2': Put failed: connection timed out
            'key3': Put failed: permission denied
        EOM

        expect { @kv.run([ '--infile', valid_file ]) }
          .to raise_error( Simp::Cli::ProcessingError,
          expected_err_msg.strip)

        expect( @output.string ).to eq(expected_stdout)
      end

    end

    context 'custom options' do
      let(:key) { 'key1' }
      let(:value) { 1 }
      let(:metadata) { {} }
      let(:json) {
        "{\"#{key}\":{\"value\":#{value},\"metadata\":#{metadata}}}"
      }

      it 'sets keys without prompting when --force' do
        mock_str = object_double('Mock Key Storer', { :put => nil })
        expect(mock_str).to receive(:put).with(key,value,metadata,false,false)
          .and_return(nil)

        allow(Simp::Cli::Kv::KeyStorer).to receive(:new)
          .with(default_env, default_backend).and_return(mock_str)

        expected_output = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.
            Set 'key1'

        EOM

        @kv.run([ '--json', json, '--force' ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'sets global keys when --global' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_str = object_double('Mock Key Storer', { :put => nil })
        expect(mock_str).to receive(:put).with(key,value,metadata,false,true)
          .and_return(nil)

        allow(Simp::Cli::Kv::KeyStorer).to receive(:new)
          .with(default_env, default_backend).and_return(mock_str)

        expected_output = <<~EOM
          Processing global 'key1'... done.
            Set 'key1'

        EOM

        @kv.run([ '--json', json, '--global' ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'sets keys for backend specified by --backend' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_str = object_double('Mock Key Storer', { :put => nil })
        expect(mock_str).to receive(:put).with(key,value,metadata,false,false)
          .and_return(nil)

        backend = 'custom_backend'
        allow(Simp::Cli::Kv::KeyStorer).to receive(:new)
          .with(default_env, backend).and_return(mock_str)

        expected_output = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.
            Set 'key1'

        EOM

        @kv.run([ '--json', json, '--backend', backend ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'sets keys for environment specified by --environment' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_str = object_double('Mock Key Storer', { :put => nil })
        expect(mock_str).to receive(:put).with(key,value,metadata,false,false)
          .and_return(nil)

        env = 'dev'
        allow(Simp::Cli::Kv::KeyStorer).to receive(:new)
          .with(env, default_backend).and_return(mock_str)

        expected_output = <<~EOM
          Processing 'key1' in '#{env}' environment... done.
            Set 'key1'

        EOM


        @kv.run([ '--json', json, '--environment', env ])
        expect( @output.string ).to eq(expected_output)
      end
    end

    context 'input data errors' do
      it 'fails to set keys when JSON file cannot be read' do
        allow(File).to receive(:read).with(any_args).and_call_original
        allow(File).to receive(:read).with('test_key.json').and_raise(
          Errno::EACCES, 'failed read')

        expect { @kv.run(['--infile', 'test_key.json']) }
          .to raise_error(Simp::Cli::ProcessingError,
          'Failed to read test_key.json: Permission denied - failed read')
      end

      it 'fails to set keys when JSON is malformed' do
        invalid_file = File.join(files_dir, 'invalid.json')
        expect { @kv.run(['--infile', invalid_file]) }
          .to raise_error(Simp::Cli::ProcessingError,
          /Invalid JSON:/)
      end

      it 'fails to set keys when JSON is not a Hash' do
        expect { @kv.run(['--json', '[1,2]']) }
          .to raise_error(Simp::Cli::ProcessingError,
          /Malformed JSON: Not a Hash/)
      end

      it 'fails to set keys when JSON is empty Hash' do
        expect { @kv.run(['--json', '{}']) }
          .to raise_error(Simp::Cli::ProcessingError,
          'No keys specified in JSON')
      end

      it "fails to set keys when JSON fails key info validation" do
        invalid_file = File.join(files_dir, 'missing_value.json')
        expect { @kv.run(['--infile', invalid_file]) }
          .to raise_error(Simp::Cli::ProcessingError,
          "Malformed JSON: Missing 'value' attribute for 'key1'")
      end
   end

    context 'option validation' do
      it 'fails if both --infile and --json are specified' do
        expect { @kv.run(['--json', '{}', '--infile', 'key.json']) }
          .to raise_error(Simp::Cli::ProcessingError,
          '--infile and --json are mutually exclusive')
      end
    end
  end
end
