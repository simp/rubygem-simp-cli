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
  let(:env_type) { :puppet }
  let(:env_name) { 'test_env_name' }
  let(:env_dir) { File.join(opts[:environmentpath], env_name) }

  describe '#initialize' do
    it { expect { described_class.new(env_type, env_name, base_env_path, opts) }.not_to raise_error }
  end

  context 'with abstract methods' do
    subject(:described_object) { described_class.new(env_type, env_name, base_env_path, opts) }

    %i[create fix update validate remove].each do |action|
      describe "##{action}" do
        it { expect { described_object.send action }.to raise_error(NotImplementedError) }
      end
    end
  end

  context 'with methods' do
    subject(:described_object) { described_class.new(env_type, env_name, base_env_path, opts) }

    describe '#selinux_fix_file_contexts' do
      before(:each) do
        allow(Facter).to receive(:value).with(anything).and_call_original
        allow(described_object).to receive(:execute)
      end

      context 'when selinux is enforcing' do
        before(:each) do
          allow(Facter).to receive(:value).with(:selinux).and_return(true)
          allow(Facter).to receive(:value).with(:selinux_current_mode).and_return('enforcing')
        end
        context 'with no paths' do
          it { expect { described_object.selinux_fix_file_contexts }.not_to raise_error }
          it 'should not attempt to execute anything' do
            described_object.selinux_fix_file_contexts
            expect(described_object).not_to have_received(:execute)
          end
        end
        context "with ['/path/to/thing']" do
          it 'runs restorecon on the paths' do
            described_object.selinux_fix_file_contexts(['/path/to/thing'])
            expect(described_object).to have_received(:execute).with('restorecon -R -F -p /path/to/thing')
          end
        end
      end

      context 'when selinux is disabled' do
        before(:each) do
          allow(Facter).to receive(:value).with(:selinux).and_return(false)
          allow(described_object).to receive(:info)
        end
        it { expect { described_object.selinux_fix_file_contexts }.not_to raise_error }
        it 'skips with an expected `info` message' do
         described_object.selinux_fix_file_contexts
         expect(described_object).to have_received(:info).with(/SELinux is disabled; skipping context restorecon for/)
        end
      end
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
    describe '#copy_skeleton_files' do

      let(:opts){ super().merge(strategy: :skeleton) }
      let(:rsync_cmd) do
        %(sg - puppet -c '/usr/bin/rsync -a --no-g "#{opts[:skeleton_path]}/" "#{env_dir}/"')
      end

      before(:each) do
        # as user root
        expect(Facter::Core::Execution).to receive(:which).with('rsync').and_return('/usr/bin/rsync')

        allow(ENV).to receive(:fetch).with(any_args).and_call_original
        allow(ENV).to receive(:fetch).with('USER').and_return('root')
        allow(described_object).to receive(:execute).with(rsync_cmd).and_return(true)

      end

      example do
        described_object.copy_skeleton_files(opts[:skeleton_path], env_dir, 'puppet')
        expect(described_object).to have_received(:execute).with(rsync_cmd)
      end
    end
  end

  describe '#fail_unless_createable' do
    subject(:described_object) { described_class.new(:test, env_name, base_env_path, opts) }
    context 'when writable environment directory is empty' do
      before(:each) do
        allow(Dir).to receive(:glob).with(any_args).and_call_original
        allow(Dir).to receive(:glob).with(File.join(env_dir, '*')).and_return([])
      end
      it { expect { described_object.fail_unless_createable }.not_to raise_error }
    end
    context 'when writable environment directory is not empty' do
      before(:each) { allow(Dir).to receive(:glob).and_return(['data', 'hiera.yaml']) }
      it {
        expect { described_object.fail_unless_createable }.to raise_error(
          Simp::Cli::ProcessingError,
          %r{already exists at '#{env_dir}'}
        )
      }
    end
  end

end
