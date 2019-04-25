require 'simp/cli/commands/environment'
require 'simp/cli/commands/environment/new'
require 'simp/cli/environment/omni_env_controller'
require 'spec_helper'

describe Simp::Cli::Commands::Environment::New do
  describe '#run' do
    context 'with default arguments' do
      subject(:run) { proc { described_class.new.run([])} }
      it 'requires an ENVIRONMENT argument' do
        allow($stdout).to receive(:write)
        allow($stderr).to receive(:write)
        expect{ run.call }.to raise_error(Simp::Cli::ProcessingError, /ENVIRONMENT.*is required/)
      end
    end

    context 'with an invalid environment' do
      it 'requires a valid ENVIRONMENT argument' do
        allow($stdout).to receive(:write)
        allow($stderr).to receive(:write)
        expect{ described_class.new.run(['.40ris']) }.to raise_error(
          Simp::Cli::ProcessingError, /is not an acceptable environment name/
        )
      end
    end

    context 'with argument `--skeleton`' do
      it 'runs OmniEnvController.create' do
        spy = spy('OmniEnvController')
        allow(Simp::Cli::Environment::OmniEnvController).to receive(:new).and_return(spy)
        allow($stdout).to receive(:write)
        allow($stderr).to receive(:write)

        described_class.new.run(['foo'])

        expect(Simp::Cli::Environment::OmniEnvController).to have_received(:new).with(hash_including({
          types: hash_including({
            puppet:    hash_including({ backend: :directory }),
            secondary: hash_including({ backend: :directory }),
            writable:  hash_including({ backend: :directory }),
          })
        }), 'foo')
        expect(spy).to have_received(:create)
      end
    end
  end
end
