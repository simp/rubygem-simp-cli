# frozen_string_literal: true

require 'simp/cli/commands/version'

describe 'Simp::Cli::Command::Version' do
  let(:files_dir) { File.join(__dir__, 'files') }

  before(:each) do
    @version = Simp::Cli::Commands::Version.new
  end

  describe '#run' do
    context 'help' do
      it 'prints help message' do
        usage = <<~EOM

          Display the current version of SIMP

          USAGE:  simp version

        EOM
        expect { @version.run(['-h']) }.to output(usage).to_stdout
        expect { @version.run(['--help']) }.to output(usage).to_stdout
      end
    end

    context 'invalid options' do
      it 'fails if any other option specified' do
        expect { @version.run(['-x']) }.to raise_error(%r{Unsupported option: -x})
      end
    end

    context 'SIMP rpm is installed' do
      it 'prints simp RPM version' do
        allow(@version).to receive(:`).with('rpm -q simp').and_return('6.4.0-0.el7.noarch')
        expect { @version.run([]) }.to output("6.4.0\n").to_stdout
      end
    end

    context 'SIMP rpm is not installed' do
      it 'fails' do
        allow(@version).to receive(:`).with('rpm -q simp').and_return('package simp is not installed')
        expect { @version.run([]) }.to raise_error(Simp::Cli::ProcessingError, %r{Version unknown})
      end
    end
  end
end
