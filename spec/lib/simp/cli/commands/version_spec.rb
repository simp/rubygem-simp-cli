require 'simp/cli/commands/version'

describe 'Simp::Cli::Command::Version' do
  let(:files_dir) { File.join(__dir__, 'files') }

  before(:each) do
    @version = Simp::Cli::Commands:: Version.new
  end

  context '#run' do
    context 'help' do
      it 'prints help message' do
        usage = <<-EOM

Display the current version of SIMP.

Usage:  simp version

EOM
        expect{ @version.run(['-h']) }.to output(usage).to_stdout
        expect{ @version.run(['--help']) }.to output(usage).to_stdout
      end
    end

    context 'invalid options' do
      it 'fails if any other option specified' do
        expect{ @version.run(['-x']) }.to raise_error(/Unsupported option: \-x/)
      end

    end
  end

end
