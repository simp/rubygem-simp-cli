require 'simp/cli/commands/kv'
require 'simp/cli/commands/kv/get'

require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Commands::Kv::Get do
  before :each do
    # expose HighLine input and output for test validation
    @input = StringIO.new
    @output = StringIO.new
    HighLine.default_instance = HighLine.new(@input, @output)

    @kv = Simp::Cli::Commands::Kv::Get.new
  end

  after :each do
    @input.close
    @output.close
    HighLine.default_instance = HighLine.new
  end

  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Kv::Get.description}/
      expect{ @kv.run(['-h']) }.to output(expected_stdout_regex).to_stdout
    end
  end

  describe '#run' do
    let(:keys_info) do
      {
        'key1' => { 'value' => 1, 'metadata' => {}},
        'key2' => { 'value' => true, 'metadata' => { 'foo'=>'bar'}},
        'key3' => { 'value' => [ 'hello', 'world'], 'metadata' => {}},
        'key4' => {
          'value'    => { 'x' => 'marks', 'the' => 'spot'},
          'metadata' => { 'on'=> 'map'}
        }
      }
    end

    let(:keys_arg) { keys_info.keys.join(',') }
    let(:default_backend) { 'default' }
    let(:default_env) { 'production' }

    context 'default options' do
      it 'retrieves keys for default env in default backend' do
        mock_rtr = object_double('Mock Key Retriever', { :get => nil })
        keys_info.each do |key, info|
          expect(mock_rtr).to receive(:get).with(key,false).and_return(info)
        end

        allow(Simp::Cli::Kv::KeyRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'key1' in 'production' environment... done.
          Processing 'key2' in 'production' environment... done.
          Processing 'key3' in 'production' environment... done.
          Processing 'key4' in 'production' environment... done.

          {
            "key1": {
              "value": 1,
              "metadata": {
              }
            },
            "key2": {
              "value": true,
              "metadata": {
                "foo": "bar"
              }
            },
            "key3": {
              "value": [
                "hello",
                "world"
              ],
              "metadata": {
              }
            },
            "key4": {
              "value": {
                "x": "marks",
                "the": "spot"
              },
              "metadata": {
                "on": "map"
              }
            }
          }
        EOM

        @kv.run([ keys_arg ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'retrieves as many keys as possible and fails with list of '\
         'key failures' do
        mock_rtr = object_double('Mock Key Retriever', { :get => nil })
        expect(mock_rtr).to receive(:get).with('key1',false)
          .and_return(keys_info['key1'])

        expect(mock_rtr).to receive(:get).with('key4',false)
          .and_return(keys_info['key4'])

        expect(mock_rtr).to receive(:get).with('key2',false).and_raise(
          Simp::Cli::ProcessingError, 'Check failed: server busy')

        expect(mock_rtr).to receive(:get).with('key3',false).and_raise(
          Simp::Cli::ProcessingError, 'Check failed: connection timed out')

        allow(Simp::Cli::Kv::KeyRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_stdout = <<~EOM
          Processing 'key1' in 'production' environment... done.
          Processing 'key2' in 'production' environment... done.
          Processing 'key3' in 'production' environment... done.
          Processing 'key4' in 'production' environment... done.

          {
            "key1": {
              "value": 1,
              "metadata": {
              }
            },
            "key4": {
              "value": {
                "x": "marks",
                "the": "spot"
              },
              "metadata": {
                "on": "map"
              }
            }
          }
        EOM

        expected_err_msg = <<~EOM
          Failed to retrieve key info for 2 out of 4 keys:
            'key2': Check failed: server busy
            'key3': Check failed: connection timed out
        EOM

        expect { @kv.run([ keys_arg ]) }
          .to raise_error( Simp::Cli::ProcessingError,
          expected_err_msg.strip)

        expect( @output.string ).to eq(expected_stdout)
      end
    end

    context 'custom options' do
      let(:key1_info_json) do
        <<~EOM
          {
            "key1": {
              "value": 1,
              "metadata": {
              }
            }
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

      it 'writes key info to file when --outfile' do
        mock_rtr = object_double('Mock Key Retriever', { :get => nil })
        expect(mock_rtr).to receive(:get).with('key1',false)
          .and_return(keys_info['key1'])

        allow(Simp::Cli::Kv::KeyRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'key1' in 'production' environment... done.

          Output for key info written to #{@outfile}
        EOM

        @kv.run([ 'key1', '--outfile', @outfile ])
        expect( @output.string ).to eq(expected_output)
        expect( File.read(@outfile) ).to eq(key1_info_json)
      end

      it 'does not write key info to file when --outfile and all queries fail' do
        mock_rtr = object_double('Mock Key Retriever', { :get => nil })
        expect(mock_rtr).to receive(:get).with('key1',false).and_raise(
          Simp::Cli::ProcessingError, 'Check failed: server busy')

        allow(Simp::Cli::Kv::KeyRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'key1' in 'production' environment... done.

        EOM

        expect { @kv.run([ 'key1', '--outfile', @outfile ]) }
          .to raise_error( Simp::Cli::ProcessingError,
          /Failed to retrieve key info/)

        expect( File.exist?(@outfile) ).to be(false)
      end

      it 'retrieves global keys when --global' do
        mock_rtr = object_double('Mock Key Retriever', { :get => nil })
        expect(mock_rtr).to receive(:get).with('key1',true)
          .and_return(keys_info['key1'])

        allow(Simp::Cli::Kv::KeyRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing global 'key1'... done.

          #{key1_info_json.strip}
        EOM

        @kv.run([ 'key1', '--global' ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'retrieves keys for backend specified by --backend' do
        mock_rtr = object_double('Mock Key Retriever', { :get => nil })
        expect(mock_rtr).to receive(:get).with('key1',false)
          .and_return(keys_info['key1'])

        backend = 'custom_backend'
        allow(Simp::Cli::Kv::KeyRetriever).to receive(:new)
          .with(default_env, backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'key1' in '#{default_env}' environment... done.

          #{key1_info_json.strip}
        EOM

        @kv.run([ 'key1', '--backend', backend ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'retrieves keys for environment specified by --environment' do
        mock_rtr = object_double('Mock Key Retriever', { :get => nil })
        expect(mock_rtr).to receive(:get).with('key1',false)
          .and_return(keys_info['key1'])

        env = 'dev'
        allow(Simp::Cli::Kv::KeyRetriever).to receive(:new)
          .with(env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'key1' in '#{env}' environment... done.

          #{key1_info_json.strip}
        EOM

        @kv.run([ 'key1', '--environment', env ])
        expect( @output.string ).to eq(expected_output)
      end
    end

    context 'option validation' do
      it 'fails if no keys are specified' do
        expect { @kv.run([]) }.to raise_error(
          Simp::Cli::ProcessingError,
          'Keys to retrieve are missing from command line')
      end
    end
  end
end
