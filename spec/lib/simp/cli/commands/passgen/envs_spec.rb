require 'simp/cli/commands/passgen'
require 'simp/cli/commands/passgen/envs'

require 'etc'
require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Commands::Passgen::Envs do
  before :each do
    @tmp_dir   = Dir.mktmpdir(File.basename(__FILE__))
    @var_dir = File.join(@tmp_dir, 'vardir')
    @puppet_env_dir = File.join(@tmp_dir, 'environments')
    @user  = Etc.getpwuid(Process.uid).name
    @group = Etc.getgrgid(Process.gid).name
    puppet_info = {
      :config => {
        'user'            => @user,
        'group'           => @group,
        'environmentpath' => @puppet_env_dir,
        'vardir'          => @var_dir
      }
    }

    # expose HighLine input and output for test validation
    @input = StringIO.new
    @output = StringIO.new
    @prev_terminal = $terminal
    $terminal = HighLine.new(@input, @output)

    allow(Simp::Cli::Utils).to receive(:puppet_info).and_return(puppet_info)
    @envs = Simp::Cli::Commands::Passgen::Envs.new

    # make sure notice and above messages are output
    @envs.set_up_global_logger(0)
  end

  after :each do
    @input.close
    @output.close
    $terminal = @prev_terminal
    FileUtils.remove_entry_secure @tmp_dir, true
  end

  let(:module_list_old_simplib) {
    <<~EOM
      /etc/puppetlabs/code/environments/production/modules
      ├── puppet-yum (v3.1.1)
      ├── puppetlabs-stdlib (v5.2.0)
      ├── simp-aide (v6.3.0)
      ├── simp-simplib (v3.15.3)
      /var/simp/environments/production/site_files
      ├── krb5_files (???)
      └── pki_files (???)
      /etc/puppetlabs/code/modules (no modules installed)
      /opt/puppetlabs/puppet/modules (no modules installed)
    EOM
  }

  let(:module_list_new_simplib) {
    module_list_old_simplib.gsub(/simp-simplib .v3.15.3/,'simp-simplib (v4.0.0)')
  }

  let(:module_list_no_simplib) {
    list = module_list_old_simplib.dup.split("\n")
    list.delete_if { |line| line.include?('simp-simplib') }
    list.join("\n") + "\n"
  }

  let(:missing_deps_warnings) {
    <<~EOM
      Warning: Missing dependency 'puppetlabs-apt':
        'puppetlabs-postgresql' (v5.12.1) requires 'puppetlabs-apt' (>= 2.0.0 < 7.0.0)
    EOM
  }

  #
  # Custom Method Tests
  #
  describe '#find_valid_environments' do
    it 'returns empty hash when Puppet environments dir is missing/inaccessible' do
      expect( @envs.find_valid_environments ).to eq({})
    end

    it 'returns empty hash when Puppet environments dir is empty' do
      FileUtils.mkdir_p(@puppet_env_dir)
      expect( @envs.find_valid_environments ).to eq({})
    end

    it 'returns empty hash when no Puppet envs have simp-simplib installed' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'dev'))
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'test'))

      module_list_results = {
        :status => true,
        :stdout => module_list_no_simplib,
        :stderr => missing_deps_warnings
      }

      [
        'puppet module list --color=false --environment=production',
        'puppet module list --color=false --environment=dev',
        'puppet module list --color=false --environment=test'
      ].each do |command|
        allow(Simp::Cli::ExecUtils).to receive(:run_command)
          .with(command, false, @envs.logger).and_return(module_list_results)
      end

      expect( @envs.find_valid_environments ).to eq({})
    end

    it 'returns hash with only Puppet envs that have simp-simplib installed' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      command = 'puppet module list --color=false --environment=production'
      module_list_results = {
        :status => true,
        :stdout => module_list_old_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @envs.logger).and_return(module_list_results)

      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'dev'))
      command = 'puppet module list --color=false --environment=dev'
      module_list_results = {
        :status => true,
        :stdout => module_list_no_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @envs.logger).and_return(module_list_results)

      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'test'))
      command = 'puppet module list --color=false --environment=test'
      module_list_results = {
        :status => true,
        :stdout => module_list_new_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @envs.logger).and_return(module_list_results)

      expected = { 'production' => '3.15.3', 'test' => '4.0.0' }
      expect( @envs.find_valid_environments ).to eq(expected)
    end

    it 'fails if puppet module list command fails' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      command = 'puppet module list --color=false --environment=production'
      module_list_results = {
        :status => false,
        :stdout => '',
        :stderr => 'some failure message'
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @envs.logger).and_return(module_list_results)

      expect{ @envs.find_valid_environments }.to raise_error(
        Simp::Cli::ProcessingError,
        "Unable to determine simplib version in 'production' environment")
    end
  end

  describe '#show_environment_list' do
    it 'lists no environments, when no environments exist' do
      expected_output =<<~EOM
        Looking for environments with simp-simplib installed... done.

        No environments with simp-simplib installed were found.

      EOM
      @envs.show_environment_list
      expect( @output.string ).to eq(expected_output)
    end

    it 'lists no environments, when no environments with simp-simplib exist' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      command = 'puppet module list --color=false --environment=production'
      module_list_results = {
        :status => true,
        :stdout => module_list_no_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @envs.logger).and_return(module_list_results)

      @envs.show_environment_list
      expected_output =<<~EOM
        Looking for environments with simp-simplib installed... done.

        No environments with simp-simplib installed were found.

      EOM
      expect( @output.string ).to eq(expected_output)
    end

    it 'lists available environments with simp-simplib installed' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      command = 'puppet module list --color=false --environment=production'
      module_list_results = {
        :status => true,
        :stdout => module_list_old_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @envs.logger).and_return(module_list_results)

      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'dev'))
      command = 'puppet module list --color=false --environment=dev'
      module_list_results = {
        :status => true,
        :stdout => module_list_no_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @envs.logger).and_return(module_list_results)

      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'test'))
      command = 'puppet module list --color=false --environment=test'
      module_list_results = {
        :status => true,
        :stdout => module_list_new_simplib,
        :stderr => missing_deps_warnings
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @envs.logger).and_return(module_list_results)

      expected_output = <<~EOM
        Looking for environments with simp-simplib installed... done.

        Environments
        ============
        production
        test

      EOM

      @envs.show_environment_list
      expect( @output.string ).to eq(expected_output)
    end

    it 'fails if puppet module list command fails' do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      command = 'puppet module list --color=false --environment=production'
      module_list_results = {
        :status => false,
        :stdout => '',
        :stderr => 'some failure message'
      }
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(command, false, @envs.logger).and_return(module_list_results)

      expect { @envs.show_environment_list }.to raise_error(
        Simp::Cli::ProcessingError,
        "Unable to determine simplib version in 'production' environment")
    end
  end

  #
  # Simp::Cli::Commands::Command API methods
  #
  describe '#help' do
    it 'should print help' do
      expected_stdout_regex = /#{Simp::Cli::Commands::Passgen::Envs.description}/
      expect{ @envs.help }.to output(expected_stdout_regex).to_stdout
    end
  end

  describe '#run' do
    before :each do
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'production'))
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'dev'))

      @module_list_command_prod =
        'puppet module list --color=false --environment=production'

      @module_list_command_dev =
        'puppet module list --color=false --environment=dev'

      @old_simplib_module_list_results = {
        :status => true,
        :stdout => module_list_old_simplib,
        :stderr => missing_deps_warnings
      }

      @new_simplib_module_list_results = {
        :status => true,
        :stdout => module_list_new_simplib,
        :stderr => missing_deps_warnings
      }
    end

    it 'lists available environments with simp-simplib installed' do
      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(@module_list_command_prod, false, @envs.logger)
        .and_return(@old_simplib_module_list_results)

      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(@module_list_command_dev, false, @envs.logger)
        .and_return(@new_simplib_module_list_results)

      expected_output = <<~EOM
        Looking for environments with simp-simplib installed... done.

        Environments
        ============
        dev
        production

      EOM

      @envs.run([])
      expect( @output.string ).to eq(expected_output)
    end
  end
end
