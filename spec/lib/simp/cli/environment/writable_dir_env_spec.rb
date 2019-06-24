# frozen_string_literal: true

require 'simp/cli/environment/writable_dir_env'
require 'spec_helper'

describe Simp::Cli::Environment::WritableDirEnv do
  # rubocop:disable RSpec/SubjectStub
  # base_opts lets us modify :opts for specific contexts
  subject(:described_object) { described_class.new(env_name, base_env_path, opts) }

  let(:base_opts) do
    {
      backend: :directory,
      environmentpath: '/opt/puppetlabs/server/data/puppetserver/simp/environments'
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

  context 'with methods' do
    describe '#create' do
      before(:each) do
        allow(described_object).to receive(:fail_unless_createable)
        allow(Dir).to receive(:glob).with(File.join(env_dir, '*')).and_return([])
      end
      context 'when strategy is :skeleton (noop)' do
        let(:opts){ super().merge(strategy: :skeleton) }
        it { expect { described_object.create }.not_to raise_error }
      end

      context 'when strategy is :copy' do
        let(:opts) do
          super().merge({
            strategy: :copy,
            src_env:  File.join(base_env_path,'src_env'),
          })
        end
        before(:each) { allow( described_object ).to receive(:copy_environment_files).with(opts[:src_env], false) }
        it { expect { described_object.create }.not_to raise_error }
        example do
          described_object.create
          expect(described_object).to have_received(:copy_environment_files).with(opts[:src_env], false)
        end
      end

      context 'when strategy is :link' do
        let(:opts) do
          super().merge({
            strategy: :link,
            src_env:  File.join(base_env_path,'src_env'),
          })
        end
        before(:each){ allow( described_object ).to receive(:link_environment_dirs).with(opts[:src_env], false) }
        it { expect { described_object.create }.not_to raise_error }
        example do
          described_object.create
          expect(described_object).to have_received(:link_environment_dirs).with(opts[:src_env], false)
        end
      end
    end

    # Writable#fix is currently inert, which is why these tests verify that it
    # does nothing.  See the #fix method's @note for details.
    describe '#fix' do
      before(:each) do
        allow(File).to receive(:directory?).with(env_dir).and_return(true)
        allow($stdout).to receive(:write)
      end

      context 'when writable environment directory is present' do
        before(:each) do
          allow(described_object).to receive(:apply_puppet_permissions).with(env_dir, false, true)
        end

        it { expect { described_object.fix }.not_to raise_error }
        example do
          described_object.fix
          expect(described_object).not_to have_received(:apply_puppet_permissions)
        end

        context 'when writable environment directory is missing' do
          before(:each) { allow(File).to receive(:directory?).with(env_dir).and_return(false) }
          it { expect { described_object.fix }.not_to raise_error }
        end
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
