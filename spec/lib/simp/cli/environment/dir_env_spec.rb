# frozen_string_literal: true

require 'simp/cli/environment/dir_env'
require 'spec_helper'

# rubocop:disable RSpec/SubjectStub
describe Simp::Cli::Environment::DirEnv do
  let(:opts) do
    skel_dir =  '/var/simp/environments'
    {
      enabled: true,
      backend: :directory,
      environmentpath:     '/var/simp/environments',
      skeleton_path:       "#{skel_dir}/secondary",
      rsync_skeleton_path: "#{skel_dir}/rsync",
    }
  end
  let(:base_env_path) { opts[:environmentpath] }
  let(:env_name) { 'test_env_name' }
  let(:env_dir) { File.join(opts[:environmentpath], env_name) }

  describe '#initialize' do
    it { expect { described_class.new(env_name, base_env_path, opts) }.not_to raise_error }
  end

  context 'with methods' do
    subject(:described_object) { described_class.new(env_name, base_env_path, opts) }

    let(:site_files_dir) { File.join(env_dir, 'site_files') }
    let(:rsync_dir) { File.join(env_dir, 'rsync') }
    let(:rsync_facl_file) { File.join(rsync_dir, '.rsync.facl') }

    before(:each) do
      # Pass through partial mocks when we don't need them
      allow(File).to receive(:directory?).with(any_args).and_call_original
      allow(File).to receive(:exist?).with(any_args).and_call_original
      allow(File).to receive(:directory?).with(opts[:environmentpath]).and_return(true)
      allow(File).to receive(:exist?).with(opts[:environmentpath]).and_return(true)
    end

    describe '#selinux_fix_file_contexts', :skip => 'TODO: implement' do
      it { expect { described_object.selinux_fix_file_contexts }.not_to raise_error }
    end

    describe '#apply_puppet_permissions' do
      subject(:apply_puppet_permissions) do
        proc { described_object.apply_puppet_permissions(env_dir, nil, true) }
      end
      before(:each) { allow(FileUtils).to receive(:chown_R).with(nil,'puppet',env_dir)}

      context 'when environment directory is present' do
        it { expect { apply_puppet_permissions.call }.not_to raise_error }
        example do
          apply_puppet_permissions.call
          expect(FileUtils).to have_received(:chown_R).with(nil,'puppet',env_dir).once
        end
      end
    end

    describe '#create' do
      it { expect { described_object.update }.to raise_error(NotImplementedError) }
    end
    describe '#fix' do
      it { expect { described_object.update }.to raise_error(NotImplementedError) }
    end

    describe '#update' do
      it { expect { described_object.update }.to raise_error(NotImplementedError) }
    end

    describe '#validate' do
      it { expect { described_object.validate }.to raise_error(NotImplementedError) }
    end

    describe '#remove' do
      it { expect { described_object.remove }.to raise_error(NotImplementedError) }
    end
  end
end
# rubocop:enable RSpec/SubjectStub

