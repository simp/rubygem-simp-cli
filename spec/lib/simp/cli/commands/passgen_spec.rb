require 'simp/cli'

describe 'Simp::Cli::Command::Passgen' do

  before(:each) do
    @passgen = Simp::Cli::Commands::Passgen.new
  end

  context '#run' do
    context 'help' do
      it 'prints help message' do
        options_help = <<~EOM

          === The SIMP Password Tool ===

          Utility to inspect and manage 'simplib::passgen' passwords

          USAGE:
            simp passgen -h
            simp passgen SUB-COMMAND -h
            simp passgen SUB-COMMAND [sub-command options]

          SUB-COMMANDS:
              envs       List environments that may have 'simplib::passgen' passwords
              list       List names of 'simplib::passgen' passwords
              remove     Remove 'simplib::passgen' passwords
              set        Set 'simplib::passgen' passwords
              show       Show 'simplib::passgen' passwords and other stored attributes

          OPTIONS:
              -h, --help                       Print this message

        EOM

        expect{ @passgen.run(['-h']) }.to output(options_help).to_stdout
      end
    end

    context 'sub-commands' do
      it 'fails when sub-command is invalid' do
        expect{ @passgen.run(['oops_command', '-h']) }.to raise_error(
          /ERROR: Did not recognize sub\-command 'oops_command \-h'/)
      end
    end
  end

end
