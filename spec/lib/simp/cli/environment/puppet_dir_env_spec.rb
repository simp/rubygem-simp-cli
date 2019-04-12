require 'simp/cli/environment/puppet_dir_env'
require 'spec_helper'

describe Simp::Cli::Environment::PuppetDirEnv do
  let(:omni_opts){ YAML.load_file(File.join(__dir__,'files/omni_env_controller_opts.yaml')) }
  let(:opts){{
    enabled: true,
    puppetfile: false,
    puppetfile_install: false,
    deploy: false,
    backend: :directory,
    environmentpath: "/etc/puppetlabs/code/environments",
  }}
  let(:env_path){ opts[:environmentpath] }

  describe '#new' do
    it 'requires an acceptable environment name' do
      expect{ described_class.new('acceptable_name', env_path, opts)}.not_to raise_error
      expect{ described_class.new('-2354', env_path, opts)}.to raise_error(ArgumentError,/Illegal environment name/)
      expect{ described_class.new('2abc_def', env_path, opts)}.to raise_error(ArgumentError,/Illegal environment name/)
    end
  end

  context 'with abstract methods' do
    subject(:described_object) { described_class.new('acceptable_name', env_path, opts) }

    describe '#create', :skip => 'TODO' do
      it{ expect{ described_object.create }.to raise_error(NotImplementedError) }
    end

    describe '#fix', :skip => 'TODO' do
      it{ expect{ described_object.fix }.to raise_error(NotImplementedError) }
    end

    describe '#update' do
      it{ expect{ described_object.update }.to raise_error(NotImplementedError) }
    end

    describe '#validate' do
      it{ expect{ described_object.validate }.to raise_error(NotImplementedError) }
    end

    describe '#remove' do
      it{ expect{ described_object.remove }.to raise_error(NotImplementedError) }
    end

  end
end
