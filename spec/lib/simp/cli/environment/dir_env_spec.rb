# frozen_string_literal: true

require 'simp/cli/environment/dir_env'
require 'spec_helper'
describe Simp::Cli::Environment::DirEnv do
  let(:opts) do
    skel_dir = '/var/simp/environments'
    {
      enabled: true,
      backend: :directory,
      environmentpath: '/var/simp/environments',
      skeleton_path: "#{skel_dir}/whatever"
    }
  end
  let(:base_env_path) { opts[:environmentpath] }
  let(:env_name) { 'test_env_name' }
  let(:env_dir) { File.join(opts[:environmentpath], env_name) }

  describe '#initialize' do
    it { expect { described_class.new(env_name, base_env_path, opts) }.not_to raise_error }
  end

  context 'with abstract methods' do
    subject(:described_object) { described_class.new(env_name, base_env_path, opts) }

    %i[create fix update validate remove].each do |action|
      describe "##{action}" do
        it { expect { described_object.send action }.to raise_error(NotImplementedError) }
      end
    end
  end

  context 'with methods' do
    subject(:described_object) { described_class.new(env_name, base_env_path, opts) }

    describe '#selinux_fix_file_contexts', :skip => 'TODO: implement' do
      it { expect { described_object.selinux_fix_file_contexts }.not_to raise_error }
    end

    describe '#apply_puppet_permissions' do
      subject(:apply_puppet_permissions) do
        proc { described_object.apply_puppet_permissions(env_dir, nil, true) }
      end

      before(:each) { allow(FileUtils).to receive(:chown_R).with(nil, 'puppet', env_dir) }

      context 'when environment directory is present' do
        it { expect { apply_puppet_permissions.call }.not_to raise_error }
        example do
          apply_puppet_permissions.call
          expect(FileUtils).to have_received(:chown_R).with(nil, 'puppet', env_dir).once
        end
      end
    end
  end
end
