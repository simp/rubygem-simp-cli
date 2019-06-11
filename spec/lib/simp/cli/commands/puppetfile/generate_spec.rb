require 'simp/cli/commands/puppetfile/generate'
require 'spec_helper'

describe Simp::Cli::Commands::Puppetfile::Generate do
  describe '#run' do
    context 'with argument `--help`' do
      it 'prints help message' do
        expect{ described_class.new.run(['-h']) }.to output(/Print a Puppetfile/).to_stdout
        expect{ described_class.new.run(['--help']) }.to output(/Print a Puppetfile/).to_stdout
      end
    end

    context 'with default arguments' do
      let(:puppetfile) { 'Mocked Puppetfile content' }

      it 'prints SIMP module Puppetfile to stdout' do
        allow(Simp::Cli::Puppetfile::LocalSimpPuppetModules).to receive(:new).and_return(
          object_double('Fake LocalSimpPuppetModules', :to_puppetfile => puppetfile)
        )
        expect{ described_class.new.run([]) }.to output("#{puppetfile}\n").to_stdout
      end
    end

    context 'with argument `--skeleton`' do
      let(:puppetfile) { 'Mocked Puppetfile content without local modules' }

      it 'prints skeleton Puppetfile to stdout' do
        allow(Simp::Cli::Puppetfile::Skeleton).to receive(:new).with(nil).and_return(
          object_double(
            Simp::Cli::Puppetfile::Skeleton.new(),
            :to_puppetfile => puppetfile
          )
        )
        expect{ described_class.new.run(['--skeleton']) }.to output("#{puppetfile}\n").to_stdout
      end
    end

    context 'with argument `--skeleton --local-modules ENV`' do
      let(:puppetfile) { 'Mocked Puppetfile content with local modules' }

      it 'prints skeleton Puppetfile with local modules to stdout' do
        allow(Simp::Cli::Puppetfile::Skeleton).to receive(:new).with('production').and_return(
          object_double(
            Simp::Cli::Puppetfile::Skeleton.new('production'),
            :to_puppetfile => puppetfile
          )
        )
        expect{ described_class.new.run(['--skeleton', '--local-modules', 'production']) }.to output("#{puppetfile}\n").to_stdout
      end
    end
  end
end
