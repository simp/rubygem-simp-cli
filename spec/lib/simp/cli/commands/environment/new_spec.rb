# frozen_string_literal: true

require 'simp/cli/commands/environment'
require 'simp/cli/commands/environment/new'
require 'simp/cli/environment/omni_env_controller'
require 'spec_helper'

describe Simp::Cli::Commands::Environment::New do
  describe '#run' do
    context 'with default arguments' do
      it 'requires an ENVIRONMENT argument' do
        expect { described_class.new.run([]) }.to raise_error(
          Simp::Cli::ProcessingError, %r{ENVIRONMENT.*is required}
      )
      end
    end

    context 'with an invalid environment' do
      it 'requires a valid ENVIRONMENT argument' do
        expect { described_class.new.run(['.40ris']) }.to raise_error(
          Simp::Cli::ProcessingError, %r{is not an acceptable environment name}
        )
      end
    end

    context 'with mutually-exclusive arguments' do
      strategies = [ ['--skeleton'], ['--copy', 'test_env2'], ['--link', 'test_env3']]
      strategies.each do |first|
        strategies.each do |second|
          next if first == second

          it "fails if #{first[0]} and #{second[0]} are both specified" do
            expect { described_class.new.run(['test_env', first, second].flatten) }.to raise_error(
              Simp::Cli::ProcessingError,
              'ERROR: Cannot specify more than one of: --skeleton, --copy, --link'
            )
          end
        end
      end
    end

    # The next 4 hashes have the following structure:
    #
    # Key   = additional args to be passed to 'simp environment new'
    # Value = expected changes to be made to the default options passed to the
    #         OmniEnvController
    skeleton_tests = {
      [ '--skeleton' ]                        => {
        :puppet      => {
          :puppetfile_generate => true,
          :puppetfile_install  => false
        },
        :description => 'create skeletons dirs and Puppetfiles'
      },
      [ '--skeleton', '--puppetfile-install'] => {
        :puppet      => {
          :puppetfile_generate => true,
          :puppetfile_install  => true
        },
        :description => 'create skeletons dirs, create Puppetfiles, and deploy modules'
      },
      [ '--skeleton', '--no-puppet-env' ]     => {
        :puppet      => { :enabled => false },
        :description => 'create secondary and writable skeleton dirs only'
      },
      [ '--skeleton', '--no-secondary-env' ]  => {
        :puppet      => { :puppetfile_generate => true },
        :secondary   => { :enabled => false },
        :description => 'create all but secondary skeletons dirs and create Puppetfiles'
      },
      [ '--skeleton', '--no-writable-env' ]   => {
        :puppet      => { :puppetfile_generate => true },
        :writable    => { :enabled => false },
        :description => 'create all but writable skeletons dirs and create Puppetfiles'
      },
      [ '--skeleton', '--no-puppetfile-gen' ] => {
        :puppet      => { :puppetfile_generate => false },
        :description => 'only create skeletons dirs'
      }
    }

    default_tests = {}
    skeleton_tests.each do |args, expected_hash|
      newargs = args.dup
      newargs.delete('--skeleton')
      default_tests[newargs] = expected_hash
    end

    copy_tests = {
      [ '--copy', 'other_env' ]                        => {
        :puppet      => { :strategy => :copy, :src_env => 'other_env'},
        :secondary   => { :strategy => :copy, :src_env => 'other_env'},
        :writable    => { :strategy => :copy, :src_env => 'other_env'},
        :description => 'copy all env dirs'
      },
      [ '--copy', 'other_env', '--puppetfile-gen'] => {
        :puppet      => {
          :strategy             => :copy,
          :src_env              => 'other_env',
          :puppetfile_generate  => true
        },
        :secondary   => { :strategy => :copy, :src_env => 'other_env'},
        :writable    => { :strategy => :copy, :src_env => 'other_env'},
        :description => 'copy all env dirs and create Puppetfiles'
      },
      [ '--copy', 'other_env', '--puppetfile-install'] => {
        :puppet       => {
          :strategy            => :copy,
          :src_env             => 'other_env',
          :puppetfile_install  => true
        },
        :secondary   => { :strategy => :copy, :src_env => 'other_env'},
        :writable    => { :strategy => :copy, :src_env => 'other_env'},
        :description => 'copy all env dirs and deploy modules'
      },
      [ '--copy', 'other_env',  '--no-puppet-env' ]     => {
        :puppet      => { :enabled => false, :strategy => :copy },
        :secondary   => { :strategy => :copy, :src_env => 'other_env' },
        :writable    => { :strategy => :copy, :src_env => 'other_env' },
        :description => 'copy secondary and writable env dirs only'
      },
      [ '--copy', 'other_env', '--no-secondary-env' ]  => {
        :puppet      => { :strategy => :copy, :src_env => 'other_env' },
        :secondary   => { :enabled => false, :strategy => :copy },
        :writable    => { :strategy => :copy, :src_env => 'other_env' },
        :description => 'copy puppet and writable env dirs only'
      },
      [ '--copy', 'other_env', '--no-writable-env' ]   => {
        :puppet      => { :strategy => :copy, :src_env => 'other_env' },
        :secondary   => { :strategy => :copy, :src_env => 'other_env' },
        :writable    => { :enabled => false, :strategy => :copy },
        :description => 'copy puppet and secondary env dirs only'
      }
    }

    link_tests = {
      [ '--link', 'other_env' ]                        => {
        :puppet      => { :strategy => :copy, :src_env => 'other_env'},
        :secondary   => { :strategy => :link, :src_env => 'other_env'},
        :writable    => { :strategy => :link, :src_env => 'other_env'},
        :description => 'copy puppet dir and link secondary and writable dirs'
      },
      [ '--link', 'other_env', '--puppetfile-gen'] => {
        :puppet      => {
          :strategy             => :copy,
          :src_env              => 'other_env',
          :puppetfile_generate  => true
        },
        :secondary   => { :strategy => :link, :src_env => 'other_env'},
        :writable    => { :strategy => :link, :src_env => 'other_env'},
        :description => 'copy puppet dir, link secondary and writable dirs, and create Puppetfiles'
      },
      [ '--link', 'other_env', '--puppetfile-install'] => {
        :puppet      => {
          :strategy            => :copy,
          :src_env             => 'other_env',
          :puppetfile_install  => true
        },
        :secondary   => { :strategy => :link, :src_env => 'other_env'},
        :writable    => { :strategy => :link, :src_env => 'other_env'},
        :description => 'copy puppet dir, link secondary and writable dirs, and deploy modules'
      },
      [ '--link', 'other_env',  '--no-puppet-env' ]     => {
        :puppet      => { :enabled => false, :strategy => :copy },
        :secondary   => { :strategy => :link, :src_env => 'other_env' },
        :writable    => { :strategy => :link, :src_env => 'other_env' },
        :description => 'link secondary and writable dirs only'
      },
      [ '--link', 'other_env', '--no-secondary-env' ]  => {
        :puppet      => { :strategy => :copy, :src_env => 'other_env' },
        :secondary   => { :enabled => false, :strategy => :link },
        :writable    => { :strategy => :link, :src_env => 'other_env' },
        :description => 'copy puppet dir and  link writable dir only'
      },
      [ '--link', 'other_env', '--no-writable-env' ]   => {
        :puppet      => { :strategy => :copy, :src_env => 'other_env' },
        :secondary   => { :strategy => :link, :src_env => 'other_env' },
        :writable    => { :enabled => false, :strategy => :link },
        :description => 'copy puppet dir and link secondary dir only'
      }
    }

    tests = {
      :default  => default_tests,
      :skeleton => skeleton_tests,
      :copy     => copy_tests,
      :link     => link_tests
    }

    # rubocop:disable RSpec/InstanceVariable
    shared_examples 'a `simp environment new` command' do |comment|
      before :each do
        @spy = instance_double('OmniEnvController')
        allow(Simp::Cli::Environment::OmniEnvController).to receive(:new).and_return(@spy)
        allow(@spy).to receive(:create)
      end

      it "instantiates OmniEnvController to #{comment}" do
        simp_env_new.call
        expect(Simp::Cli::Environment::OmniEnvController).to have_received(:new).with(
          expected_hash, expected_environment
        )
      end

      it 'calls OmniEnvController.create' do
        simp_env_new.call
        expect(@spy).to have_received(:create)
      end
    end
    # rubocop:enable RSpec/InstanceVariable

    let(:default_puppet_hash_opts){ {
      enabled: true,
      strategy: :skeleton,
      puppetfile_generate: false,
      puppetfile_install: false,
      backend: :directory,
#      environmentpath: '/etc/puppetlabs/code/environments',
      skeleton_path: '/usr/share/simp/environment-skeleton/puppet',
      module_repos_path: '/usr/share/simp/git/puppet_modules',
      skeleton_modules_path: '/usr/share/simp/modules',
    } }

    let(:default_secondary_hash_opts){ {
      enabled: true,
      strategy: :skeleton,
      backend: :directory,
      environmentpath: '/var/simp/environments',
      skeleton_path: '/usr/share/simp/environment-skeleton/secondary',
      rsync_skeleton_path: '/usr/share/simp/environment-skeleton/rsync',
      tftpboot_src_path: '/var/www/yum/**/images/pxeboot',
      tftpboot_dest_path: 'rsync/RedHat/Global/tftpboot/linux-install',
    } }

    let(:default_writable_hash_opts){ {
      enabled: true,
      strategy: :skeleton,
      backend: :directory,
#      environmentpath: '/opt/puppetlabs/server/data/puppetserver/simp/environments'
    } }

    let(:puppet_hash_opts){ hash_including(default_puppet_hash_opts) }
    let(:secondary_hash_opts){ hash_including(default_secondary_hash_opts) }
    let(:writable_hash_opts){  hash_including(default_writable_hash_opts) }

    let(:expected_hash) do
      hash_including(
        types: hash_including(
          puppet:    puppet_hash_opts,
          secondary: secondary_hash_opts,
          writable:  writable_hash_opts
        )
      )
    end

    tests.each do |strategy, test_params|
      context "with #{strategy} strategy" do
        let(:expected_environment){ 'development' }
        let(:base_cli_args) { [expected_environment, '--console-only'] }

        test_params.each do |args, expected_hash|
          full_args = (['development', '--console-only'] << args).flatten
          context "with args '#{full_args.join(' ')}'" do
            subject(:simp_env_new){ Proc.new { described_class.new.run(cli_args) } }
            let(:cli_args){ full_args }
            let(:puppet_hash_opts) {
              changes = expected_hash[:puppet]
              changes = {} if changes.nil?
              hash_including(default_puppet_hash_opts.merge(changes))
            }

            let(:secondary_hash_opts) {
              changes = expected_hash[:secondary]
              changes = {} if changes.nil?
              hash_including(default_secondary_hash_opts.merge(changes))
            }

            let(:writable_hash_opts) {
              changes = expected_hash[:writable]
              changes = {} if changes.nil?
              hash_including(default_writable_hash_opts.merge(changes))
            }

           include_examples 'a `simp environment new` command', expected_hash[:description]

          end
        end
      end
    end
  end
end
