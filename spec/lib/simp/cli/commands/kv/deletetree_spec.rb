require 'simp/cli/commands/kv'
require 'simp/cli/commands/kv/deletetree'

require 'spec_helper'

describe Simp::Cli::Commands::Kv::Deletetree do
  before :each do
    # expose HighLine input and output for test validation
    @input = StringIO.new
    @output = StringIO.new
    HighLine.default_instance = HighLine.new(@input, @output)

    @kv = Simp::Cli::Commands::Kv::Deletetree.new
  end

  after :each do
    @input.close
    @output.close
    HighLine.default_instance = HighLine.new
  end

  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Kv::Deletetree.description}/
      expect{ @kv.run(['-h']) }.to output(expected_stdout_regex).to_stdout
    end
  end

  describe '#run' do
    let(:folders) { [ 'folder1', 'folder2', 'folder3', 'folder4' ] }
    let(:folders_arg) { folders.join(',') }
    let(:default_backend) { 'default' }
    let(:default_env) { 'production' }

    context 'default options' do
      it 'removes folders for default env in default backend when prompt '\
         'returns yes' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_del = object_double('Mock Key Deleter', { :deletetree => nil })
        folders.each do |folder|
          expect(mock_del).to receive(:deletetree).with(folder,false).and_return(nil)
        end

        allow(Simp::Cli::Kv::TreeDeleter).to receive(:new)
          .with(default_env, default_backend).and_return(mock_del)

        expected_output = <<~EOM
          Processing 'folder1' in '#{default_env}' environment... done.
            Removed 'folder1'

          Processing 'folder2' in '#{default_env}' environment... done.
            Removed 'folder2'

          Processing 'folder3' in '#{default_env}' environment... done.
            Removed 'folder3'

          Processing 'folder4' in '#{default_env}' environment... done.
            Removed 'folder4'

        EOM

        @kv.run([ folders_arg ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'does not remove folders for default env in default backend when '\
         'prompt returns no' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(false)
        mock_del = object_double('Mock Key Deleter', { :deletetree => nil })
        allow(Simp::Cli::Kv::TreeDeleter).to receive(:new)
          .with(default_env, default_backend).and_return(mock_del)

        expected_output = <<~EOM
          Skipped 'folder1' in '#{default_env}' environment

          Skipped 'folder2' in '#{default_env}' environment

          Skipped 'folder3' in '#{default_env}' environment

          Skipped 'folder4' in '#{default_env}' environment

        EOM

        @kv.run([ folders_arg ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'removes as many folders as possible and fails with list of folder '\
         'remove failures' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_del = object_double('Mock Key Deleter', { :deletetree => nil })
        expect(mock_del).to receive(:deletetree).with('folder1',false).and_return(nil)
        expect(mock_del).to receive(:deletetree).with('folder4',false).and_return(nil)
        expect(mock_del).to receive(:deletetree).with('folder2',false).and_raise(
          Simp::Cli::ProcessingError, 'Remove failed: folder not found')

        expect(mock_del).to receive(:deletetree).with('folder3',false).and_raise(
          Simp::Cli::ProcessingError, 'Remove failed: permission denied')

        allow(Simp::Cli::Kv::TreeDeleter).to receive(:new)
          .with(default_env, default_backend).and_return(mock_del)

        expected_stdout = <<~EOM
          Processing 'folder1' in '#{default_env}' environment... done.
            Removed 'folder1'

          Processing 'folder2' in '#{default_env}' environment... done.
            Skipped 'folder2'

          Processing 'folder3' in '#{default_env}' environment... done.
            Skipped 'folder3'

          Processing 'folder4' in '#{default_env}' environment... done.
            Removed 'folder4'

        EOM

        expected_err_msg = <<~EOM
          Failed to remove 2 out of 4 folders:
            'folder2': Remove failed: folder not found
            'folder3': Remove failed: permission denied
        EOM

        expect { @kv.run([ folders_arg ]) }
          .to raise_error( Simp::Cli::ProcessingError,
          expected_err_msg.strip)

        expect( @output.string ).to eq(expected_stdout)
      end
    end

    context 'custom options' do
      it 'removes folders without prompting when --force' do
        mock_del = object_double('Mock Key Deleter', { :deletetree => nil })
        expect(mock_del).to receive(:deletetree).with('folder1',false).and_return(nil)

        allow(Simp::Cli::Kv::TreeDeleter).to receive(:new)
          .with(default_env, default_backend).and_return(mock_del)

        expected_output = <<~EOM
          Processing 'folder1' in '#{default_env}' environment... done.
            Removed 'folder1'

        EOM

        @kv.run([ 'folder1', '--force' ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'removes global folders when --global' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_del = object_double('Mock Key Deleter', { :deletetree => nil })
        expect(mock_del).to receive(:deletetree).with('folder1',true).and_return(nil)

        allow(Simp::Cli::Kv::TreeDeleter).to receive(:new)
          .with(default_env, default_backend).and_return(mock_del)

        expected_output = <<~EOM
          Processing global 'folder1'... done.
            Removed 'folder1'

        EOM

        @kv.run([ 'folder1', '--global' ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'removes folders for backend specified by --backend' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_del = object_double('Mock Key Deleter', { :deletetree => nil })
        expect(mock_del).to receive(:deletetree).with('folder1',false).and_return(nil)

        backend = 'custom_backend'
        allow(Simp::Cli::Kv::TreeDeleter).to receive(:new)
          .with(default_env, backend).and_return(mock_del)

        expected_output = <<~EOM
          Processing 'folder1' in '#{default_env}' environment... done.
            Removed 'folder1'

        EOM

        @kv.run([ 'folder1', '--backend', backend ])
        expect( @output.string ).to eq(expected_output)
      end

      it 'removes folders for environment specified by --environment' do
        allow(Simp::Cli::Utils).to receive(:yes_or_no).and_return(true)
        mock_del = object_double('Mock Key Deleter', { :deletetree => nil })
        expect(mock_del).to receive(:deletetree).with('folder1',false).and_return(nil)

        env = 'dev'
        allow(Simp::Cli::Kv::TreeDeleter).to receive(:new)
          .with(env, default_backend).and_return(mock_del)

        expected_output = <<~EOM
          Processing 'folder1' in '#{env}' environment... done.
            Removed 'folder1'

        EOM


        @kv.run([ 'folder1', '--environment', env ])
        expect( @output.string ).to eq(expected_output)
      end
    end

    context 'option validation' do
      it 'fails if no folders are specified' do
        expect { @kv.run([]) }.to raise_error(
          Simp::Cli::ProcessingError,
          'Folders to remove are missing from command line')
      end
    end
  end
end
