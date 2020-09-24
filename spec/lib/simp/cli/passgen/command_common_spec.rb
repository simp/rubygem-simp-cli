require 'simp/cli/passgen/command_common'
require 'simp/cli/passgen/legacy_password_manager'
require 'simp/cli/passgen/password_manager'

require 'etc'
require 'spec_helper'
require 'tmpdir'

class PassgenCommandCommonTester
  include Simp::Cli::Passgen::CommandCommon
end

describe Simp::Cli::Passgen::CommandCommon do
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

    @production_env_dir = File.join(@puppet_env_dir, 'production')
    FileUtils.mkdir_p(@production_env_dir)
    @module_list_command_prod =
      'puppet module list --color=false --environment=production'

    # expose HighLine input and output for test validation
    @input = StringIO.new
    @output = StringIO.new
    HighLine.default_instance = HighLine.new(@input, @output)

    allow(Simp::Cli::Utils).to receive(:puppet_info).and_return(puppet_info)
    @passgen_cmd = PassgenCommandCommonTester.new
  end

  after :each do
    @input.close
    @output.close
    HighLine.default_instance = HighLine.new
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

  describe '#get_password_manager' do
    let(:opts_simpkv) {{
      :env     => 'production',
      :backend => 'default',
      :folder  => 'app1'
    }}

    let(:opts_legacy) {{
      :env          => 'production',
      :password_dir => '/path/to/passwords'
    }}

    it 'returns current password manager when environment has simp-simplib >= 4.0.0' do
      module_list_results = {
        :status => true,
        :stdout => module_list_new_simplib,
        :stderr => missing_deps_warnings
      }

      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(@module_list_command_prod, false, @passgen_cmd.logger)
        .and_return(module_list_results)

      expect( Simp::Cli::Passgen::PasswordManager ).to receive(:new)
        .with(opts_simpkv[:env], opts_simpkv[:backend], opts_simpkv[:folder])
        .and_call_original

      manager = @passgen_cmd.get_password_manager(opts_simpkv)
      expect( manager.is_a?(Simp::Cli::Passgen::PasswordManager) ).to be true
    end

    it 'returns legacy password manager when environment has simp-simplib < 4.0.0' do
      module_list_results = {
        :status => true,
        :stdout => module_list_old_simplib,
        :stderr => missing_deps_warnings
      }

      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(@module_list_command_prod, false, @passgen_cmd.logger)
        .and_return(module_list_results)

      expect( Simp::Cli::Passgen::LegacyPasswordManager ).to receive(:new)
        .with(opts_legacy[:env], opts_legacy[:password_dir])
        .and_call_original

      manager =  @passgen_cmd.get_password_manager(opts_legacy)
      expect( manager.is_a?(Simp::Cli::Passgen::LegacyPasswordManager) ).to be true
    end

    it 'fails when Puppet environment does not exist' do
      FileUtils.rm_rf(@production_env_dir)
      expect { @passgen_cmd.get_password_manager(opts_simpkv) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Invalid Puppet environment 'production': Does not exist")
    end

    it 'fails when simp-simplib is not installed in Puppet environment' do
      module_list_results = {
        :status => true,
        :stdout => module_list_no_simplib,
        :stderr => missing_deps_warnings
      }

      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(@module_list_command_prod, false, @passgen_cmd.logger)
        .and_return(module_list_results)

      expect { @passgen_cmd.get_password_manager(opts_simpkv) }.to raise_error(
          Simp::Cli::ProcessingError,
          "Invalid Puppet environment 'production': " +
          'simp-simplib is not installed')
    end

    it 'fails when LegacyPasswordManager cannot be constructed' do
      allow(@passgen_cmd).to receive(:get_simplib_version).and_return('3.0.0')
      password_env_dir = File.join(@var_dir, 'simp', 'environments')
      default_password_dir = File.join(password_env_dir, 'production',
        'simp_autofiles', 'gen_passwd')

      FileUtils.mkdir_p(File.dirname(default_password_dir))
      FileUtils.touch(default_password_dir)
      opts = { :env => 'production' }
      expect { @passgen_cmd.get_password_manager(opts) }.to raise_error(
        Simp::Cli::ProcessingError,
        "Password directory '#{default_password_dir}' is not a directory")
    end
  end

  describe '#get_simplib_version' do
    it 'returns simp-simplib version when simp-simplib is in the environment' do
      module_list_results = {
        :status => true,
        :stdout => module_list_new_simplib,
        :stderr => missing_deps_warnings
      }

      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(@module_list_command_prod, false, @passgen_cmd.logger)
        .and_return(module_list_results)

      expect( @passgen_cmd.get_simplib_version('production') ).to eq('4.0.0')
    end

    it 'returns nil when simp-simplib is not in the environment' do
      module_list_results = {
        :status => true,
        :stdout => module_list_no_simplib,
        :stderr => missing_deps_warnings
      }

      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(@module_list_command_prod, false, @passgen_cmd.logger)
        .and_return(module_list_results)

      expect( @passgen_cmd.get_simplib_version('production') ).to be_nil
    end

    it 'fails if puppet module list command fails' do
      module_list_results = {
        :status => false,
        :stdout => '',
        :stderr => 'some failure message'
      }

      allow(Simp::Cli::ExecUtils).to receive(:run_command)
        .with(@module_list_command_prod, false, @passgen_cmd.logger)
        .and_return(module_list_results)

      expect { @passgen_cmd.get_simplib_version('production') }.to raise_error(
        Simp::Cli::ProcessingError,
        "Unable to determine simplib version in 'production' environment")
    end
  end

  describe '#legacy_passgen?' do
    it 'should return true for old simplib' do
      expect( @passgen_cmd.legacy_passgen?('3.17.0') ).to eq(true)
    end

    it 'should return false for new simplib' do
      expect( @passgen_cmd.legacy_passgen?('4.0.1') ).to eq(false)
    end
  end

  describe '#translate_bool' do
    it 'should translate true to enabled' do
      expect( @passgen_cmd.translate_bool(true) ).to eq('enabled')
    end

    it 'should translate false to disabled' do
      expect( @passgen_cmd.translate_bool(false) ).to eq('disabled')
    end
  end
end
