# frozen_string_literal: true

require 'simp/cli/environment/puppet_dir_env'
require 'spec_helper'

describe Simp::Cli::Environment::PuppetDirEnv do
  # rubocop:disable RSpec/SubjectStub
  subject(:described_object) { described_class.new(env_name, base_env_path, opts) }

  let(:base_opts)  do
    skel_dir =  '/var/simp/environments'
    share_dir = '/usr/share/simp'
    {
      puppetfile_generate: false,
      puppetfile_install: false,
      deploy: false,
      backend: :directory,
      environmentpath: '/etc/puppetlabs/code/environments',
      skeleton_path: "#{skel_dir}/simp",
      module_repos_path: "#{share_dir}/git/puppet_modules",
      skeleton_modules_path: "#{share_dir}/modules"
    }
  end
  let(:opts) { base_opts }
  let(:base_env_path) { opts[:environmentpath] }
  let(:env_name) { 'test_env_name' }
  let(:env_dir) { File.join(opts[:environmentpath], env_name) }
  let(:simp_git_dir) { '/usr/share/simp/git/puppet_modules' }

  describe '#new' do
    # rubocop:disable RSpec/MultipleExpectations
    it 'requires an acceptable environment name' do
      expect { described_class.new('acceptable_name', base_env_path, opts) }.not_to raise_error
      expect { described_class.new('-2354', base_env_path, opts) }.to raise_error(ArgumentError, %r{Illegal environment name})
      expect { described_class.new('2abc_def', base_env_path, opts) }.to raise_error(ArgumentError, %r{Illegal environment name})
    end
    # rubocop:enable RSpec/MultipleExpectations
  end

  describe '#copy_skeleton_files' do
    let(:rsync_cmd) do
      %(sg - puppet -c '/usr/bin/rsync -a --no-g "#{opts[:skeleton_path]}/" "#{env_dir}/" 2>&1')
    end

    before(:each) do
      # as user root
      allow(ENV).to receive(:fetch).with(any_args).and_call_original
      allow(ENV).to receive(:fetch).with('USER').and_return('root')
      allow(described_object).to receive(:execute).with(rsync_cmd).and_return(true)
    end

    example do
      described_object.copy_skeleton_files(opts[:skeleton_path], env_dir, 'puppet')
      expect(described_object).to have_received(:execute).with(rsync_cmd)
    end
  end

  context 'with methods' do
    describe '#create', :skip => 'TODO: implement' do
      context 'when puppet environment directory is empty (not deployed)' do
        before(:each) do
          allow(Dir).to receive(:glob).with(any_args).and_call_original
          allow(Dir).to receive(:glob).with(File.join(env_dir, '*')).and_return([])
          allow(described_object).to receive(:copy_skeleton_files).with(
            opts[:skeleton_path], env_dir, 'puppet'
          )
        end
        it { expect { described_object.create }.not_to raise_error }
        it {
          described_object.create
          expect(described_object).to have_received(:copy_skeleton_files).with(
            opts[:skeleton_path], env_dir, 'puppet'
          )
        }
      end

      context 'when puppet environment directory is not empty' do
        before(:each) { allow(Dir).to receive(:glob).and_return(['data', 'hiera.yaml']) }
        it {
          expect { described_object.create }.to raise_error(
            Simp::Cli::ProcessingError,
            %r{already exists at '#{env_dir}'}
          )
        }
      end
    end

    describe '#fix' do
      before(:each) do
        allow(File).to receive(:directory?).with(env_dir).and_return(true)
        allow($stdout).to receive(:write)
      end

      context 'when puppet environment directory is present' do
        before(:each) do
          allow(described_object).to receive(:apply_puppet_permissions).with(env_dir, true, true)
        end

        it { expect { described_object.fix }.not_to raise_error }
        it {
          described_object.fix
          expect(described_object).to have_received(:apply_puppet_permissions).with(env_dir, true, true).once
        }
      end

      context 'when puppet environment directory is missing' do
        before(:each) { allow(File).to receive(:directory?).with(env_dir).and_return(false) }
        it {
          expect { described_object.fix }.to raise_error(
            Simp::Cli::ProcessingError,
            %r{directory not found at '#{env_dir}'}
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
  # rubocop:enable RSpec/SubjectStub
end
