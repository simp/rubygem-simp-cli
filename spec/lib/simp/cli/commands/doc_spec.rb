require 'simp/cli/commands/doc'

describe 'Simp::Cli::Command::Doc' do
  let(:files_dir) { File.join(__dir__, 'files') }

  before(:each) do
    @doc = Simp::Cli::Commands::Doc.new
  end

  context '#run' do
    context 'help' do
      it 'prints help message' do
        usage = <<~EOM

          === The SIMP Doc Tool ===
          Show SIMP documentation in elinks, a text-based web browser

          USAGE:  simp doc

        EOM
        expect{ @doc.run(['-h']) }.to output(usage).to_stdout
        expect{ @doc.run(['--help']) }.to output(usage).to_stdout
      end
    end

    context 'invalid options' do
      it 'fails if any other option specified' do
        expect{ @doc.run(['-x']) }.to raise_error(/Unsupported option: \-x/)
      end

    end
  end

end
