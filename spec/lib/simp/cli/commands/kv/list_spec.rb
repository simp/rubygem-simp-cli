require 'simp/cli/commands/kv'
require 'simp/cli/commands/kv/list'

require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Commands::Kv::List do
  before :each do
    # expose HighLine input and output for test validation
    @input = StringIO.new
    @output = StringIO.new
    HighLine.default_instance = HighLine.new(@input, @output)

    @kv = Simp::Cli::Commands::Kv::List.new
  end

  after :each do
    @input.close
    @output.close
    HighLine.default_instance = HighLine.new
  end

  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Kv::List.description}/
      expect{ @kv.run(['-h']) }.to output(expected_stdout_regex).to_stdout
    end
  end

  describe '#run' do
    let(:folders_info) do
      {
        'folder1' => {
          'keys' => {
            'key1_1' => { 'value' => 1, 'metadata' => {}},
            'key1_2' => { 'value' => true, 'metadata' => { 'foo'=>'bar'}}
          },
          'folders' => [
            'sub1_1',
            'sub1_2'
          ]
        },
        'folder2' => {
          'keys' => {},
          'folders' => [
            'sub2_1',
            'sub2_2'
          ]
        },
        'folder3' => {
          'keys' => {
            'key3_1' => { 'value' => [ 'hello', 'world'], 'metadata' => {}},
            'key3_2' => {
              'value'    => { 'x' => 'marks', 'the' => 'spot'},
              'metadata' => { 'on'=> 'map'}
            }
          },
          'folders' => []
        },
        'folder4' => {
          'keys' => {},
          'folders' => []
        },
      }
    end

    let(:folders_arg) { folders_info.keys.join(',') }
    let(:default_backend) { 'default' }
    let(:default_env) { 'production' }

    context 'default options' do
      it 'retrieves folder list for default env in default backend' do
        mock_rtr = object_double('Mock List Retriever', { :list => nil })
        folders_info.each do |folder, list|
          expect(mock_rtr).to receive(:list).with(folder,false).and_return(list)
        end

        allow(Simp::Cli::Kv::ListRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'folder1' in 'production' environment... done.
          Processing 'folder2' in 'production' environment... done.
          Processing 'folder3' in 'production' environment... done.
          Processing 'folder4' in 'production' environment... done.

          {
            "folder1": {
              "keys": [
                "key1_1",
                "key1_2"
              ],
              "folders": [
                "sub1_1",
                "sub1_2"
              ]
            },
            "folder2": {
              "keys": [],
              "folders": [
                "sub2_1",
                "sub2_2"
              ]
            },
            "folder3": {
              "keys": [
                "key3_1",
                "key3_2"
              ],
              "folders": []
            },
            "folder4": {
              "keys": [],
              "folders": []
            }
          }
        EOM

        @kv.run([ folders_arg ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'retrieves as many folder listings s as possible and fails with list '\
         'of folder/key failures' do
        mock_rtr = object_double('Mock List Retriever', { :list => nil })
        expect(mock_rtr).to receive(:list).with('folder1',false)
          .and_return(folders_info['folder1'])

        expect(mock_rtr).to receive(:list).with('folder4',false)
          .and_return(folders_info['folder4'])

        expect(mock_rtr).to receive(:list).with('folder2',false).and_raise(
          Simp::Cli::ProcessingError, 'Check failed: server busy')

        expect(mock_rtr).to receive(:list).with('folder3',false).and_raise(
          Simp::Cli::ProcessingError, 'Check failed: connection timed out')

        allow(Simp::Cli::Kv::ListRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_stdout = <<~EOM
          Processing 'folder1' in 'production' environment... done.
          Processing 'folder2' in 'production' environment... done.
          Processing 'folder3' in 'production' environment... done.
          Processing 'folder4' in 'production' environment... done.

          {
            "folder1": {
              "keys": [
                "key1_1",
                "key1_2"
              ],
              "folders": [
                "sub1_1",
                "sub1_2"
              ]
            },
            "folder4": {
              "keys": [],
              "folders": []
            }
          }
        EOM

        expected_err_msg = <<~EOM
          Failed to retrieve list for 2 out of 4 folders:
            'folder2': Check failed: server busy
            'folder3': Check failed: connection timed out
        EOM

        expect { @kv.run([ folders_arg ]) }
          .to raise_error( Simp::Cli::ProcessingError,
          expected_err_msg.strip)

        expect( @output.string ).to eq(expected_stdout)
      end
    end

    context 'custom options' do
      let(:folder1_info_json) do
        <<~EOM
          {
            "folder1": {
              "keys": [
                "key1_1",
                "key1_2"
              ],
              "folders": [
                "sub1_1",
                "sub1_2"
              ]
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

      it 'lists full key info when --no-brief' do
        mock_rtr = object_double('Mock List Retriever', { :list => nil })
        expect(mock_rtr).to receive(:list).with('folder1',false)
          .and_return(folders_info['folder1'])

        allow(Simp::Cli::Kv::ListRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'folder1' in '#{default_env}' environment... done.

          {
            "folder1": {
              "keys": {
                "key1_1": {
                  "value": 1,
                  "metadata": {}
                },
                "key1_2": {
                  "value": true,
                  "metadata": {
                    "foo": "bar"
                  }
                }
              },
              "folders": [
                "sub1_1",
                "sub1_2"
              ]
            }
          }
        EOM

        @kv.run([ 'folder1', '--no-brief'])
        expect( @output.string ).to eq(expected_output)
      end

      it 'writes list results to file when --outfile' do
        mock_rtr = object_double('Mock List Retriever', { :list => nil })
        expect(mock_rtr).to receive(:list).with('folder1',false)
          .and_return(folders_info['folder1'])

        allow(Simp::Cli::Kv::ListRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'folder1' in 'production' environment... done.

          Output for list written to #{@outfile}
        EOM

        @kv.run([ 'folder1', '--outfile', @outfile ])
        expect( @output.string ).to eq(expected_output)
        expect( File.read(@outfile) ).to eq(folder1_info_json)
      end

      it 'does not write list results to file when --outfile and all queries fail' do
        mock_rtr = object_double('Mock List Retriever', { :list => nil })
        expect(mock_rtr).to receive(:list).with('folder1',false).and_raise(
          Simp::Cli::ProcessingError, 'Check failed: server busy')

        allow(Simp::Cli::Kv::ListRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'folder1' in 'production' environment... done.

        EOM

        expect { @kv.run([ 'folder1', '--outfile', @outfile ]) }
          .to raise_error( Simp::Cli::ProcessingError,
          /Failed to retrieve list/)

        expect( File.exist?(@outfile) ).to be(false)
      end

      it 'retrieves global folder lists when --global' do
        mock_rtr = object_double('Mock List Retriever', { :list => nil })
        expect(mock_rtr).to receive(:list).with('folder1',true)
          .and_return(folders_info['folder1'])

        allow(Simp::Cli::Kv::ListRetriever).to receive(:new)
          .with(default_env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing global 'folder1'... done.

          #{folder1_info_json.strip}
        EOM

        @kv.run([ 'folder1', '--global' ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'lists folders for backend specified by --backend' do
        mock_rtr = object_double('Mock List Retriever', { :list => nil })
        expect(mock_rtr).to receive(:list).with('folder1',false)
          .and_return(folders_info['folder1'])

        backend = 'custom_backend'
        allow(Simp::Cli::Kv::ListRetriever).to receive(:new)
          .with(default_env, backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'folder1' in '#{default_env}' environment... done.

          #{folder1_info_json.strip}
        EOM

        @kv.run([ 'folder1', '--backend', backend ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'lists folders for environment specified by --environment' do
        mock_rtr = object_double('Mock List Retriever', { :list => nil })
        expect(mock_rtr).to receive(:list).with('folder1',false)
          .and_return(folders_info['folder1'])

        env = 'dev'
        allow(Simp::Cli::Kv::ListRetriever).to receive(:new)
          .with(env, default_backend).and_return(mock_rtr)

        expected_output = <<~EOM
          Processing 'folder1' in '#{env}' environment... done.

          #{folder1_info_json.strip}
        EOM

        @kv.run([ 'folder1', '--environment', env ])
        expect( @output.string ).to eq(expected_output)
      end
    end

    context 'option validation' do
      it 'fails if no folders are specified' do
        expect { @kv.run([]) }.to raise_error(
          Simp::Cli::ProcessingError,
          'Folders to list are missing from command line')
      end
    end
  end
end
