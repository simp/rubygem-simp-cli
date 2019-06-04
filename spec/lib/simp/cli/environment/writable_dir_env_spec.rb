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
    describe '#create', :skip => 'TODO: Implement' do
      context 'when writable environment directory is empty' do
        before(:each) do
          allow(Dir).to receive(:glob).with(any_args).and_call_original
          allow(Dir).to receive(:glob).with(File.join(env_dir, '*')).and_return([])
        end
        it { expect { described_object.create }.not_to raise_error }
        it {
          described_object.create
        }
      end

      context 'when writable environment directory is not empty' do
        before(:each) { allow(Dir).to receive(:glob).and_return(['data', 'hiera.yaml']) }
        it {
          expect { described_object.create }.to raise_error(
            Simp::Cli::ProcessingError,
            %r{already exists at '#{env_dir}'}
          )
        }
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
