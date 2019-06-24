# frozen_string_literal: true

require 'simp/cli/environment/omni_env_controller'
require 'simp/cli/environment/puppet_dir_env'
require 'simp/cli/environment/secondary_dir_env'
require 'simp/cli/environment/writable_dir_env'
require 'spec_helper'
require 'yaml'

describe Simp::Cli::Environment::OmniEnvController do
  OMNI_ENVIRONMENT  = %i[puppet secondary writable].freeze
  EXTRA_ENVIRONMENT = %i[secondary writable].freeze

  subject(:described_object) { described_class.new(opts, 'foo') }

  let(:opts_yaml) { File.read(File.join(__dir__, 'files/omni_env_controller_opts.yaml')) }
  let(:opts) { YAML.load(opts_yaml) }

  let(:opts_pup_disabled) do
    opts = YAML.load(opts_yaml)
    opts[:types][:puppet][:enabled] = false
    opts
  end

  shared_examples 'it delegates to enabled Env objects' do |method, expected_envs|
    let(:spies) do
      {
        # rubocop:disable RSpec/VerifiedDoubles
        puppet: spy('puppet environment spy'),
        secondary: spy('secondary environment spy'),
        writable: spy('writable environment spy')
        # rubocop:enable RSpec/VerifiedDoubles
      }
    end

    before(:each) do
      allow(Simp::Cli::Environment::PuppetDirEnv).to receive(:new).and_return(spies[:puppet])
      allow(Simp::Cli::Environment::SecondaryDirEnv).to receive(:new).and_return(spies[:secondary])
      allow(Simp::Cli::Environment::WritableDirEnv).to receive(:new).and_return(spies[:writable])
      allow($stdout).to receive(:write)
    end

    it "calls #{method}() for enabled environments: #{expected_envs.map(&:to_s).join(', ')}" do
      subject.call
      spies.select { |k, _v| expected_envs.include?(k) }.each do |_env, spy|
        expect(spy).to have_received(method).once
      end
    end

    disabled_envs = OMNI_ENVIRONMENT - expected_envs
    unless disabled_envs.empty?
      it "does not call #{method}() for disabled environment: #{disabled_envs.join(', ')}" do
        subject.call
        spies.select { |k, _v| expected_envs.include?(k) }.each do |_env, spy|
          expect(spy).to have_received(method).once
        end
      end
    end
  end

  describe '#new' do
    subject(:new) { proc { described_class.new(opts, 'foo') } }

    it { expect { new.call }.not_to raise_error }
    it { expect(new.call).to be_a described_class }
  end

  describe '#create' do
    subject(:create) { proc { described_object.create } }

    it_behaves_like 'it delegates to enabled Env objects', :fail_unless_createable, OMNI_ENVIRONMENT
    it_behaves_like 'it delegates to enabled Env objects', :create, OMNI_ENVIRONMENT
    it_behaves_like 'it delegates to enabled Env objects', :fix,    EXTRA_ENVIRONMENT
    context 'when the Puppet environment is not enabled' do
      let(:opts) { opts_pup_disabled }

      it_behaves_like 'it delegates to enabled Env objects', :fail_unless_createable, %i[secondary writable]
      it_behaves_like 'it delegates to enabled Env objects', :create, %i[secondary writable]
      it_behaves_like('it delegates to enabled Env objects', :fix, %i[secondary writable])
    end
  end

  describe '#fix' do
    subject(:fix) { proc { described_object.create } }

    it_behaves_like 'it delegates to enabled Env objects', :fix, %i[puppet secondary writable]
    context 'when the Puppet environment is not enabled' do
      let(:opts) { opts_pup_disabled }

      it_behaves_like('it delegates to enabled Env objects', :fix, EXTRA_ENVIRONMENT)
    end
  end
end
