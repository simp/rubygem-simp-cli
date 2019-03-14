require 'simp/cli/commands/puppetfile/generate'
require 'spec_helper'

describe Simp::Cli::Commands::Puppetfile::Generate do
  describe '#run' do
    context 'with default arguments' do
      subject(:run) { proc { described_class.new.run([])} }
      it 'prints puppetfile to stdout' do
        allow(Simp::Cli::Puppetfile::LocalSimpPuppetModules).to receive(:new).and_return(
          object_double('Fake LocalSimpPuppetModules', :to_puppetfile => 'Mocked Puppetfile content')
        )
        expect{ run.call }.to output("Mocked Puppetfile content\n").to_stdout
      end
    end
    context 'with argument `--skeleton`' do
      subject(:run_sk) { proc { described_class.new.run(['--skeleton'])} }
      it 'prints puppetfile to stdout' do
        allow(Simp::Cli::Puppetfile::Skeleton).to receive(:to_puppetfile).and_return(
          'Mocked Puppetfile content'
        )
        expect{ run_sk.call }.to output("Mocked Puppetfile content\n").to_stdout
      end
    end
  end
end
