# frozen_string_literal: true

require 'simp/cli/commands/environment'
require 'simp/cli/commands/environment/new'
require 'simp/cli/environment/omni_env_controller'
require 'spec_helper'

describe Simp::Cli::Commands::Environment::New do
  describe '#run' do
    context 'with default arguments' do
      subject(:run) { proc { described_class.new.run([]) } }

      it 'requires an ENVIRONMENT argument' do
        allow($stdout).to receive(:write)
        allow($stderr).to receive(:write)
        expect { run.call }.to raise_error(Simp::Cli::ProcessingError, %r{ENVIRONMENT.*is required})
      end
    end

    context 'with an invalid environment' do
      it 'requires a valid ENVIRONMENT argument' do
        allow($stdout).to receive(:write)
        allow($stderr).to receive(:write)
        expect { described_class.new.run(['.40ris']) }.to raise_error(
          Simp::Cli::ProcessingError, %r{is not an acceptable environment name}
        )
      end
    end

    context 'with argument `--skeleton`' do
      let(:omni_spy) { instance_double('OmniEnvController') }

      before(:each) do
        allow(Simp::Cli::Environment::OmniEnvController).to receive(:new).and_return(omni_spy)
        allow(omni_spy).to receive(:create)
        allow($stdout).to receive(:write)
        allow($stderr).to receive(:write)
      end

      it 'runs OmniEnvController#create' do
        described_class.new.run(['foo'])

        expect(Simp::Cli::Environment::OmniEnvController).to have_received(:new).with(
          hash_including(
            types: hash_including(
              puppet: hash_including(backend: :directory),
              secondary: hash_including(backend: :directory),
              writable: hash_including(backend: :directory)
            )
          ), 'foo'
        )
      end

      it 'runs OmniEnvController#create' do
        described_class.new.run(['foo'])
        expect(omni_spy).to have_received(:create).once
      end
    end
  end
end
