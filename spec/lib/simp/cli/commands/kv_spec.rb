require 'simp/cli'

describe 'Simp::Cli::Command::Kv' do

  before(:each) do
    @kv = Simp::Cli::Commands::Kv.new
  end

  context '#run' do
    context 'help' do
      it 'prints help message' do
        options_help = <<~EOM

          === The SIMP Key/Value Store Tool ===

          Utility to inspect and manage content in key/value stores

          USAGE:
            simp kv -h
            simp kv SUB-COMMAND -h
            simp kv SUB-COMMAND [sub-command options]

          SUB-COMMANDS:
              delete         Delete keys from a libkv backend
              deletetree     Delete folders from a libkv backend
              exists         Check for existence of keys/folders in a libkv backend
              get            Retrieve values and metadata for keys in a libkv backend
              list           List the contents of a folder in a libkv backend
              put            Set the value and metadata for keys in a libkv backend

          OPTIONS:
              -h, --help                       Print this message

        EOM

        expect{ @kv.run(['-h']) }.to output(options_help).to_stdout
      end
    end

    context 'sub-commands' do
      it 'fails when sub-command is invalid' do
        expect{ @kv.run(['oops_command', '-h']) }.to raise_error(
          /ERROR: Did not recognize sub\-command 'oops_command \-h'/)
      end
    end
  end

end
