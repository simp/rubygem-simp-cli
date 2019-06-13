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
        expect { run.call }.to raise_error(Simp::Cli::ProcessingError, %r{ENVIRONMENT.*is required})
      end
    end

    context 'with an invalid environment' do
      it 'requires a valid ENVIRONMENT argument' do
        expect { described_class.new.run(['.40ris']) }.to raise_error(
          Simp::Cli::ProcessingError, %r{is not an acceptable environment name}
        )
      end
    end

    # rubocop:disable RSpec/InstanceVariable
    shared_examples 'a `simp environment new` command' do
      before :each do
        @spy = instance_double('OmniEnvController')
        allow(Simp::Cli::Environment::OmniEnvController).to receive(:new).and_return(@spy)
        allow(@spy).to receive(:create)
      end

      it 'instantiates OmniEnvController with expected options' do
        simp_env_new.call
        expect(Simp::Cli::Environment::OmniEnvController).to have_received(:new).with(
          expected_hash, expected_environment
        )
      end

      it 'calls OmniEnvController.create' do
        simp_env_new.call
        expect(@spy).to have_received(:create)
      end
    end
    # rubocop:enable RSpec/InstanceVariable

    shared_examples 'with --no-puppet-env' do
      context 'with --no-puppet-env' do
        let(:cli_args){ super() << '--no-puppet-env' }
        let(:puppet_hash_opts){ hash_including( enabled: false) }
        include_examples 'a `simp environment new` command'
      end
    end

    shared_examples 'with an additional --skeleton arg' do
      context 'with --skeleton' do
        let(:cli_args){ super() << '--skeleton'}
        it do
          expect{simp_env_new.call }.to raise_error(
            Simp::Cli::ProcessingError,
            'ERROR: Cannot specify more than one of: --skeleton, --copy, --link'
          )
        end
      end
    end

    let(:normal_hash_opts){ hash_including(enabled: true, backend: :directory, strategy: :skeleton) }
    let(:puppet_hash_opts){ normal_hash_opts }
    let(:secondary_hash_opts){ normal_hash_opts }
    let(:writable_hash_opts){ normal_hash_opts }
    let(:expected_hash) do
      hash_including(
        types: hash_including(
          puppet:    puppet_hash_opts,
          secondary: secondary_hash_opts,
          writable:  writable_hash_opts
        )
      )
    end

    context 'with `simp environment new development`' do
      subject(:simp_env_new){ Proc.new { described_class.new.run(cli_args) } }
      let(:cli_args){ ['development'] }
      let(:expected_environment){ 'development' }

      include_examples 'a `simp environment new` command'
      include_examples 'with --no-puppet-env'
      context 'with --skeleton' do
        let(:cli_args){ super() << '--skeleton' }
        include_examples 'a `simp environment new` command' # should be identical
      end

      context 'with --puppetfile --puppetfile-install' do
        let(:cli_args){ super() << '--puppetfile' << '--puppetfile-install' }
        let(:puppet_hash_opts) do
          hash_including(enabled: true, strategy: :skeleton, puppetfile_generate: true, puppetfile_install: true )
        end
        include_examples 'a `simp environment new` command'
        include_examples 'with --no-puppet-env'
      end

    end

    context 'with `simp environment new staging --link production`' do
      let(:cli_args){ [ 'staging', '--link', 'production' ] }
      subject(:simp_env_new){ Proc.new { described_class.new.run(cli_args) } }
      let(:expected_environment){ 'staging' }
      let(:normal_hash_opts){ hash_including(enabled: true, backend: :directory, strategy: :link, src_env: 'production') }
      let(:puppet_hash_opts) do
        hash_including(
          enabled: true, backend: :directory, strategy: :copy,
          puppetfile_generate: false, puppetfile_install: false
        )
      end
      include_examples 'a `simp environment new` command'
      include_examples 'with --no-puppet-env'
      include_examples 'with an additional --skeleton arg'
    end

    context 'with `simp environment new new_prod --copy production`' do
      let(:cli_args){ [ 'new_prod', '--copy', 'production' ] }
      subject(:simp_env_new){ Proc.new { described_class.new.run(cli_args) } }
      let(:expected_environment){ 'new_prod' }
      let(:normal_hash_opts){ hash_including(enabled: true, backend: :directory, strategy: :copy, src_env: 'production') }
      include_examples 'a `simp environment new` command'
      include_examples 'with --no-puppet-env'
      include_examples 'with an additional --skeleton arg'
    end
  end
end
