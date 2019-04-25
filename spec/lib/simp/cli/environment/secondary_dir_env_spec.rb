# frozen_string_literal: true

require 'simp/cli/environment/secondary_dir_env'
require 'spec_helper'

# rubocop:disable RSpec/SubjectStub
describe Simp::Cli::Environment::SecondaryDirEnv do
  let(:omni_opts) { YAML.load_file(File.join(__dir__, 'files/omni_env_controller_opts.yaml')) }
  let(:opts) do
    {
      enabled: true,
      backend: :directory,
      environmentpath: '/var/simp/environments'
    }
  end
  let(:env_path) { opts[:environmentpath] }

  describe '#new' do
    it { expect { described_class.new('acceptable_name', env_path, opts) }.not_to raise_error }
    it { expect { described_class.new('-2354', env_path, opts) }.to raise_error(ArgumentError, %r{Illegal environment name}) }
    it { expect { described_class.new('2abc_def', env_path, opts) }.to raise_error(ArgumentError, %r{Illegal environment name}) }
  end

  context 'with methods' do
    subject(:described_object) { described_class.new(mod_name, env_path, opts) }

    let(:mod_name) { 'test_env_name' }
    let(:mod_dir) { File.join(opts[:environmentpath], mod_name) }
    let(:site_files_dir) { File.join(mod_dir, 'site_files') }
    let(:rsync_dir) { File.join(mod_dir, 'rsync') }
    let(:rsync_facl_file) { File.join(rsync_dir, '.rsync.facl') }

    before(:each) do
      # Pass through partial mocks when we don't need them
      allow(File).to receive(:directory?).with(any_args).and_call_original
      allow(File).to receive(:exist?).with(any_args).and_call_original
      allow(File).to receive(:directory?).with(opts[:environmentpath]).and_return(true)
      allow(File).to receive(:exist?).with(opts[:environmentpath]).and_return(true)
    end

    describe '#create' do
      it { expect { described_object.create }.not_to raise_error }
    end

    describe '#fix' do
      before(:each) { allow(File).to receive(:exist?).with(mod_dir).and_return(true) }

      context 'when secondary environment directory is present' do
        before(:each) do
          puts "site_file_dirs = '#{site_files_dir}'"
          allow(described_object).to receive(:selinux_fix_file_contexts).with([mod_dir])
          allow(described_object).to receive(:apply_puppet_permissions).with(site_files_dir, false, true)
          allow(described_object).to receive(:apply_facls).with(rsync_dir, rsync_facl_file)
        end

        it { expect { described_object.fix }.not_to raise_error }
        it {
          described_object.fix
          expect(described_object).to have_received(:selinux_fix_file_contexts).with([mod_dir]).once
        }
        it {
          described_object.fix
          expect(described_object).to have_received(:apply_puppet_permissions).with(site_files_dir, false, true).once
        }
        it {
          described_object.fix
          expect(described_object).to have_received(:apply_facls).with(rsync_dir, rsync_facl_file).once
        }
      end

      context 'when secondary environment directory is missing' do
        before(:each) { allow(File).to receive(:exist?).with(mod_dir).and_return(false) }
        it {
          expect { described_object.fix }.to raise_error(
            Simp::Cli::ProcessingError,
            %r{directory not found at '#{mod_dir}'}
          )
        }
      end
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
