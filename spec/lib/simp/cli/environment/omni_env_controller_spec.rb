# frozen_string_literal: true

require 'simp/cli/environment/omni_env_controller'
require 'simp/cli/environment/puppet_dir_env'
require 'simp/cli/environment/secondary_dir_env'
require 'simp/cli/environment/writable_dir_env'
require 'spec_helper'
require 'yaml'

describe Simp::Cli::Environment::OmniEnvController do
  OPTS_YAML = <<-OPTS.gsub(%r{^ {4}}, '')
    ---
    :strategy: :skeleton
    :types:
      :puppet:
        :enabled: true
        :puppetfile: false
        :puppetfile_install: false
        :deploy: false
        :backend: :directory
        :environmentpath: "/etc/puppetlabs/code/environments"
      :secondary:
        :enabled: true
        :backend: :directory
        :environmentpath: "/var/simp/environments"
      :writable:
        :enabled: true
        :backend: :directory
        :environmentpath: "/opt/puppetlabs/server/data/puppetserver/simp"
  OPTS

  subject(:described_object) { described_class.new(opts, 'foo') }

  let(:opts) do
    YAML.load(OPTS_YAML)
  end

  let(:opts_pup_disabled) do
    opts = YAML.load(OPTS_YAML)
    opts[:types][:puppet][:enabled] = false
    opts
  end

  shared_examples 'it delegates to enabled Env objects' do |method, num|
    it "invokes #{method}() on #{num} environments" do
      # rubocop:disable RSpec/VerifiedDoubles
      spy = spy('shared environment spy')
      # rubocop:enable RSpec/VerifiedDoubles
      allow(Simp::Cli::Environment::PuppetDirEnv).to receive(:new).and_return(spy)
      allow(Simp::Cli::Environment::SecondaryDirEnv).to receive(:new).and_return(spy)
      allow(Simp::Cli::Environment::WritableDirEnv).to receive(:new).and_return(spy)
      allow($stdout).to receive(:write)

      subject.call
      expect(spy).to have_received(method.to_sym).exactly(num).times
    end
  end

  describe '#new' do
    subject(:new) { proc { described_class.new(opts, 'foo') } }

    it { expect { new.call }.not_to raise_error }
    it { expect(new.call).to be_a described_class }
  end

  describe '#create' do
    subject(:create) { proc { described_object.create } }

    it_behaves_like 'it delegates to enabled Env objects', :create, 3
    it_behaves_like 'it delegates to enabled Env objects', :fix, 3
    context 'when the Puppet environment is not enabled' do
      let(:opts) { opts_pup_disabled }

      it_behaves_like 'it delegates to enabled Env objects', :create, 2
      it_behaves_like('it delegates to enabled Env objects', :fix, 2)
    end
  end

  describe '#fix' do
    subject(:create) { proc { described_object.create } }

    it_behaves_like 'it delegates to enabled Env objects', :fix, 3
    context 'when the Puppet environment is not enabled' do
      let(:opts) { opts_pup_disabled }

      it_behaves_like('it delegates to enabled Env objects', :fix, 2)
    end
  end
end
