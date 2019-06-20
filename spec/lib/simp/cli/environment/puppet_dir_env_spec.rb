# frozen_string_literal: true

require 'simp/cli/environment/puppet_dir_env'
require 'simp/cli/puppetfile/local_simp_puppet_modules'
require 'simp/cli/puppetfile/skeleton'

require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Environment::PuppetDirEnv do
  subject(:described_object) { described_class.new(env_name, base_env_path, opts) }

  let(:base_opts)  do
    skel_dir =  '/var/simp/environments'
    share_dir = '/usr/share/simp'
    {
      puppetfile_generate: false,
      puppetfile_install: false,
      backend: :directory,
      environmentpath: '/etc/puppetlabs/code/environments',
      skeleton_path: "#{share_dir}/environment-skeleton/puppet",
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

  context 'with methods' do
    describe '#create' do
      before(:each) do
        allow(Dir).to receive(:glob).with(File.join(env_dir, '*')).and_return([])
      end

      context 'when strategy is :skeleton' do
        let(:opts){ super().merge(strategy: :skeleton) }

        before(:each) do
          allow(described_object).to receive(:fail_unless_createable)
          allow(described_object).to receive(:create_environment_from_skeleton)
        end
        it { expect { described_object.create }.not_to raise_error }
        it {
          described_object.create
          expect(described_object).to have_received(:fail_unless_createable)
          expect(described_object).to have_received(:create_environment_from_skeleton)
        }
      end

      context 'when strategy is :copy' do
        let(:opts) do
          super().merge({
            strategy: :copy,
            src_env:  File.join(base_env_path,'src_env'),
          })
        end
        before(:each) do
          allow(described_object).to receive(:fail_unless_createable)
          allow(described_object).to receive(:create_environment_from_copy)
        end
        it { expect { described_object.create }.not_to raise_error }
        example do
          described_object.create
          expect(described_object).to have_received(:fail_unless_createable)
          expect(described_object).to have_received(:create_environment_from_copy)
        end
      end

      context 'when strategy is :link' do
        let(:opts) do
          super().merge({
            strategy: :link,
            src_env:  File.join(base_env_path,'src_env'),
          })
        end
        before(:each) do
          allow(described_object).to receive(:fail_unless_createable)
          allow(described_object).to receive(:create_environment_from_link)
        end
        it { expect { described_object.create }.not_to raise_error }
        example do
          described_object.create
          expect(described_object).to have_received(:fail_unless_createable)
          expect(described_object).to have_received(:create_environment_from_link)
        end
      end

      context 'when strategy is not set' do
        before(:each) {
          allow(described_object).to receive(:fail_unless_createable)
        }
        it {
          expect { described_object.create }.to raise_error(
            RuntimeError,
            %r{ERROR: Unknown Puppet environment create strategy: ''}
          )
        }
      end

      context 'when puppet environment directory is not empty' do
        let(:opts){ super().merge(strategy: :skeleton) }
        before(:each) {
          allow(Dir).to receive(:glob).with(File.join(env_dir, '*')).and_return(['data', 'hiera.yaml'])
        }
        it {
          expect { described_object.create }.to raise_error(
            Simp::Cli::ProcessingError,
            %r{already exists at '#{env_dir}'}
          )
        }
      end
    end

    describe '#create_environment_from_copy' do
      before(:each) { allow( described_object ).to receive(:copy_environment_files).with(opts[:src_env]) }
      it { expect { described_object.create_environment_from_copy }.not_to raise_error }
      example do
        described_object.create_environment_from_copy
        expect(described_object).to have_received(:copy_environment_files).with(opts[:src_env])
      end
      context 'with :puppetfile_generate option' do
        let(:opts){ super().merge(puppetfile_generate: true)}
        before :each do
          allow(described_object).to receive(:puppetfile_generate)
        end
        example do
          described_object.create_environment_from_copy
          expect(described_object).to have_received(:puppetfile_generate).once
        end
      end

      context 'with :puppetfile_install option' do
        let(:opts){ super().merge(puppetfile_install: true)}
        before :each do
          allow(described_object).to receive(:puppetfile_install)
        end
        example do
          described_object.create_environment_from_copy
          expect(described_object).to have_received(:puppetfile_install).once
        end
      end
    end

    describe '#create_environment_from_link' do
      before(:each){ allow( described_object ).to receive(:link_environment_dirs).with(opts[:src_env]) }
      it { expect { described_object.create_environment_from_link }.not_to raise_error }
      example do
        described_object.create_environment_from_link
        expect(described_object).to have_received(:link_environment_dirs).with(opts[:src_env])
      end
      context 'with :puppetfile_generate option' do
        let(:opts){ super().merge(puppetfile_generate: true)}
        before :each do
          allow(described_object).to receive(:puppetfile_generate)
        end
        example do
          described_object.create_environment_from_link
          expect(described_object).to have_received(:puppetfile_generate).once
        end
      end

      context 'with :puppetfile_install option' do
        let(:opts){ super().merge(puppetfile_install: true)}
        before :each do
          allow(described_object).to receive(:puppetfile_install)
        end
        example do
          described_object.create_environment_from_link
          expect(described_object).to have_received(:puppetfile_install).once
        end
      end
    end

    describe '#create_environment_from_skeleton' do
      before(:each) do
        allow(FileUtils).to receive(:mkdir_p).with(any_args).and_call_original
        allow(FileUtils).to receive(:mkdir_p).with(env_dir, mode: 0755)
        allow(described_object).to receive(:copy_skeleton_files).with(
          opts[:skeleton_path], env_dir, 'puppet'
        )
        allow(described_object).to receive(:template_environment_conf)
      end

      it { expect { described_object.create_environment_from_skeleton }.not_to raise_error }
      example do
        described_object.create_environment_from_skeleton
        expect(described_object).to have_received(:copy_skeleton_files).with(
          opts[:skeleton_path], env_dir, 'puppet'
        )
      end
      it { expect { described_object.create_environment_from_skeleton }.not_to raise_error }

      context 'with :puppetfile_generate option' do
        let(:opts){ super().merge(puppetfile_generate: true)}
        before :each do
          allow(described_object).to receive(:puppetfile_generate)
        end
        example do
          described_object.create_environment_from_skeleton
          expect(described_object).to have_received(:puppetfile_generate).once
        end
      end

      context 'with :puppetfile_install option' do
        let(:opts){ super().merge(puppetfile_install: true)}
        before :each do
          allow(described_object).to receive(:puppetfile_install)
        end
        example do
          described_object.create_environment_from_skeleton
          expect(described_object).to have_received(:puppetfile_install).once
        end
      end
    end

    describe '#puppetfile_generate' do
      let(:puppetfile_simp_content) { 'Puppetfile.simp content' }
      let(:puppetfile_content) { 'Puppetfile content' }
      before :each do
        @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__))
        @env_name = 'test_env'
        @opts = {
          strategy: :skeleton,
          puppetfile_generate: true,
          backend: :directory,
          environmentpath: File.join(@tmp_dir, 'puppet', 'environments'),
          skeleton_path: File.join(@tmp_dir, 'skeleton', 'puppet'),
          module_repos_path: File.join(@tmp_dir, 'puppet_modules'),
          skeleton_modules_path: File.join(@tmp_dir, 'module')
        }
        FileUtils.mkdir_p(File.join(@opts[:environmentpath], @env_name))
        @puppetfile = File.join(@opts[:environmentpath], @env_name, 'Puppetfile')
        @puppetfile_simp = "#{@puppetfile}.simp"

        allow(Simp::Cli::Puppetfile::LocalSimpPuppetModules).to receive(:new).and_return(
          object_double('Fake LocalSimpPuppetModules', :to_puppetfile => puppetfile_simp_content)
        )

        allow(Simp::Cli::Puppetfile::Skeleton).to receive(:new).and_return(
          object_double('Fake Skeleton', :to_puppetfile => puppetfile_content)
        )

      end

      after :each do
        FileUtils.remove_entry_secure @tmp_dir
      end

      it 'should generate Puppetfile.simp and Puppetfile when none exist' do
        env_object = described_class.new(@env_name, @opts[:environmentpath], @opts)
        env_object.puppetfile_generate

        expect(File.exist?(@puppetfile)).to be true
        expect(File.read(@puppetfile)).to eq "#{puppetfile_content}\n"
        expect(File.exist?(@puppetfile_simp)).to be true
        expect(File.read(@puppetfile_simp)).to eq "#{puppetfile_simp_content}\n"
      end

      it 'should generate Puppetfile.simp, only, when Puppetfile exists' do
        File.open(@puppetfile, 'w') { |file| file.puts 'old Puppetfile content' }
        env_object = described_class.new(@env_name, @opts[:environmentpath], @opts)
        env_object.puppetfile_generate

        expect(File.exist?(@puppetfile)).to be true
        expect(File.read(@puppetfile)).to eq "old Puppetfile content\n"
        expect(File.exist?(@puppetfile_simp)).to be true
        expect(File.read(@puppetfile_simp)).to eq "#{puppetfile_simp_content}\n"
      end

      it 'should generate Puppetfile.simp only when both exist' do
        File.open(@puppetfile, 'w') { |file| file.puts 'old Puppetfile content' }
        File.open(@puppetfile_simp, 'w') { |file| file.puts 'old Puppetfile.simp content' }
        env_object = described_class.new(@env_name, @opts[:environmentpath], @opts)
        env_object.puppetfile_generate

        expect(File.exist?(@puppetfile)).to be true
        expect(File.read(@puppetfile)).to eq "old Puppetfile content\n"
        expect(File.exist?(@puppetfile_simp)).to be true
        expect(File.read(@puppetfile_simp)).to eq "#{puppetfile_simp_content}\n"
      end
    end

    describe '#puppetfile_install' do
      let(:r10k_cmd) { '/usr/share/simp/bin/r10k puppetfile install -v info' }
      before :each do
        @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__))
        @env_name = 'test_env'
        @opts = {
          strategy: :skeleton,
          puppetfile_install: true,
          backend: :directory,
          environmentpath: File.join(@tmp_dir, 'puppet', 'environments'),
          skeleton_path: File.join(@tmp_dir, 'skeleton', 'puppet'),
          module_repos_path: File.join(@tmp_dir, 'puppet_modules'),
          skeleton_modules_path: File.join(@tmp_dir, 'module')
        }
        FileUtils.mkdir_p(File.join(@opts[:environmentpath], @env_name))
        allow(File).to receive(:executable?).with(any_args).and_call_original
        allow(File).to receive(:executable?).with('/usr/share/simp/bin/r10k').and_return(true)
      end

      after :each do
        FileUtils.remove_entry_secure @tmp_dir
      end

      it 'should execute r10K' do
        env_object = described_class.new(@env_name, @opts[:environmentpath], @opts)
        allow(env_object).to receive(:execute).with(r10k_cmd).and_return(true)
        env_object.puppetfile_install
        expect(env_object).to have_received(:execute).with(r10k_cmd)
      end

      it 'should fail when r10k fails' do
        env_object = described_class.new(@env_name, @opts[:environmentpath], @opts)
        allow(env_object).to receive(:execute).with(r10k_cmd).and_return(false)
        expect { env_object.puppetfile_install }.to raise_error(
          Simp::Cli::ProcessingError,
          /ERROR:  Failed to install Puppet modules using r10k/
        )
      end
    end

    pending '#template_environment_conf'

    describe '#fix' do
      before(:each) do
        allow(File).to receive(:directory?).with(env_dir).and_return(true)
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
end
