require 'simp/cli/commands/puppetfile/generate'
require 'spec_helper'

describe Simp::Cli::Commands::Puppetfile::Generate do
  describe '#run' do
    context 'with default arguments' do
      it 'prints puppetfile to stdout' do
        allow(Simp::Cli::Puppetfile::LocalSimpPuppetModules).to receive(:new).and_return(
          object_double('Fake LocalSimpPuppetModules', :to_puppetfile => 'Mocked Puppetfile content')
        )
        expect{ subject.run ['generate'] }.to output("Mocked Puppetfile content\n").to_stdout
      end
    end
    context 'with argument `--skeleton`' do
      it 'prints puppetfile to stdout'
    end
  end
end
