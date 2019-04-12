require 'simp/cli/environment/writable_dir_env'
require 'spec_helper'

describe Simp::Cli::Environment::WritableDirEnv do
  let(:omni_opts){ YAML.load_file(File.join(__dir__,'files/omni_env_controller_opts.yaml')) }
  let(:opts){{
    enabled: true,
    backend: :directory,
    environmentpath: "/var/simp/environments"
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

    describe '#create' do
      it{ expect{ described_object.create }.not_to raise_error }
    end

    describe '#fix' do
      it{ expect{ described_object.fix }.not_to raise_error }
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
