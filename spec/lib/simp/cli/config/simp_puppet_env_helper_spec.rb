require 'simp/cli/config/simp_puppet_env_helper'
require 'rspec/its'
require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Config::SimpPuppetEnvHelper do

  before :each do
    @puppet_env_files_dir =  File.join(__dir__, '..', 'commands', 'files')
    @sec_env_files_dir =  File.join(__dir__, 'items', 'action', 'files')
    @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__))
    @env = 'production'
    @puppet_env_dir = File.join(@tmp_dir, 'puppet', @env)
    @puppet_env_datadir = File.join(@puppet_env_dir, 'data')
    @puppet_env_root_dir = File.dirname(@puppet_env_dir)
    @secondary_env_dir = File.join(@tmp_dir, 'secondary', @env)
    @writable_env_dir = File.join(@tmp_dir, 'writable', @env)

    modulepath = [
      File.join(@puppet_env_dir, 'modules'),
      File.join(@secondary_env_dir, 'site_files')
    ].join(':')

    @system_puppet_info = {
      :config                     => {
        'modulepath' => modulepath,
      },
      :puppet_group               => 'puppet',
      :version                    => '5.5.10',
      :environment_path           => File.dirname(@puppet_env_dir),
      :secondary_environment_path => File.dirname(@secondary_env_dir),
      :writable_environment_path  => File.dirname(@writable_env_dir)
    }

    @start_time =  Time.new(2017, 1, 13, 11, 42, 3)
    @env_helper = Simp::Cli::Config::SimpPuppetEnvHelper.new(@env, @start_time)
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe '#back_up_puppet_environment' do
    let(:file_content) { 'Original file content' }
    it 'should backup an puppet env when the backup parent dir does not exist' do
      puppet_env_dir = File.join(@tmp_dir, 'environments', 'production')
      FileUtils.mkdir_p(puppet_env_dir)

      # work around private method...
      @env_helper.send(:back_up_puppet_environment, puppet_env_dir)

      expect( Dir.exist?(puppet_env_dir) ).to be false
      expected_parent_dir = File.join(@tmp_dir, 'environments.bak')
      expect( Dir.exist?(expected_parent_dir) ).to be true

      expected_dir = File.join(expected_parent_dir, 'production.20170113T114203')
      expect( Dir.exist?(expected_dir) ).to be true
    end

    it 'should backup an puppet env when the backup parent dir does exist' do
      puppet_env_dir = File.join(@tmp_dir, 'environments', 'production')
      FileUtils.mkdir_p(puppet_env_dir)
      expected_parent_dir = File.join(@tmp_dir, 'environments.bak')
      FileUtils.mkdir_p(expected_parent_dir)

      @env_helper.send(:back_up_puppet_environment, puppet_env_dir)

      expect( Dir.exist?(puppet_env_dir) ).to be false
      expected_dir = File.join(expected_parent_dir, 'production.20170113T114203')
      expect( Dir.exist?(expected_dir) ).to be true
    end

    it 'should do nothing when the puppet env to back up does not exist' do
      puppet_env_dir = File.join(@tmp_dir, 'environments', 'production')

      @env_helper.send(:back_up_puppet_environment, puppet_env_dir)

      expected_parent_dir = File.join(@tmp_dir, 'environments.bak')
      expect( Dir.exist?(expected_parent_dir) ).to be false
    end
  end

  describe '#create' do
    # FIXME Need to mock module repos, env skeletons, etc. for OmniEnvController
    #       to do its work, or test this via 'simp config' in an acceptance test
    pending 'should return new env info after create' do
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)

      expect( @env_helper.env_status[0] ).to eq :creatable

      env_info = @env_helper.create

      expected = {
        :puppet_config      => @system_puppet_info[:config],
        :puppet_group       => 'puppet',
        :puppet_version     => '5.5.10',
        :puppet_env         => 'production',
        :puppet_env_dir     => @puppet_env_dir,
        :puppet_env_datadir => @puppet_env_datadir, # should be now set instead of nil
        :secondary_env_dir  => @secondary_env_dir,
        :writable_env_dir   => @writable_env_dir
      }

      expect( env_info ).to eq expected

      expect( @env_helper.env_status[0] ).to eq :exists
    end

    it 'should backup existing Puppet environment' do
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)
      allow(Simp::Cli::Environment::OmniEnvController).to \
        receive(:new).and_return(
          object_double('Mock OmniEnvController', :create => true)
        )

      FileUtils.mkdir_p(@puppet_env_dir)

      @env_helper.create

      expected_backup_dir = File.join(@tmp_dir, 'puppet.bak', "#{@env}.20170113T114203")
      expect( Dir.exist?(expected_backup_dir) ).to be true
    end

    # OmniEnvController.create failure cases?
    #   raises RuntimeError if cannot determine puppet_info[:puppet_group]
    #   raises RuntimeError if rsync command could not be found
    #   raises RuntimeError if rsync fails
    #   raises Simp::Cli::ProcessingError if any skeleton source directory
    #     to be copied does not exist
    #   raises Simp::Cli::ProcessingError if any puppet env contains modules
    #   raises Simp::Cli::ProcessingError if any puppet env dir is missing
    #   raises RuntimeError if an environment.conf.TEMPLATE does not exist
    #   raises RuntimeError if r10K install command fails
    #   raises Simp::Cli::ProcessingError if secondary env path exists
    #   ...
  end

  describe '#env_info' do
    let(:system_puppet_info) {{
      :config                     => {
        'modulepath' => '/some/path1:/some/path2'
      },
      :puppet_group               => 'puppet',
      :version                    => '5.5.10',
      :environment_path           => '/etc/puppetlabs/puppet/code/environments',
      :secondary_environment_path => '/var/simp/environments',
      :writable_environment_path  => '/opt/puppetlabs/server/data/puppetserver/simp/environments',
      :is_pe                      => false
    }}

    let(:datadir) { '/etc/puppetlabs/puppet/code/environments/production/data' }

    it 'returns Hash of info about the SIMP omni-environment' do
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(system_puppet_info)
      allow(@env_helper).to receive(:get_puppet_env_datadir).and_return(datadir)

      expected = {
        :puppet_config      => system_puppet_info[:config],
        :puppet_group       => 'puppet',
        :puppet_version     => '5.5.10',
        :puppet_env         => 'production',
        :puppet_env_dir     => '/etc/puppetlabs/puppet/code/environments/production',
        :puppet_env_datadir => datadir,
        :secondary_env_dir  => '/var/simp/environments/production',
        :writable_env_dir   => '/opt/puppetlabs/server/data/puppetserver/simp/environments/production',
        :is_pe              => false
      }
      expect( @env_helper.env_info).to eq expected
    end
  end

  describe '#env_status' do
    code_map = {
      # pup env   sec env      aggregate
      [:missing, :missing] => :creatable,
      [:missing, :present] => :invalid,
      [:missing, :invalid] => :invalid,
      [:empty,   :missing] => :creatable,
      [:empty,   :present] => :invalid,
      [:empty,   :invalid] => :invalid,
      [:present, :missing] => :invalid,
      [:present, :present] => :exists,
      [:present, :invalid] => :invalid,
      [:invalid, :missing] => :invalid,
      [:invalid, :present] => :invalid,
      [:invalid, :invalid] => :invalid,
    }

    [:missing, :empty, :present, :invalid].each do |pup_env_code|
      [:missing, :present, :invalid].each do |sec_env_code|
        status_code = code_map[[pup_env_code, sec_env_code]]
        it "returns #{status_code} for pup env #{pup_env_code} and sec env #{sec_env_code}" do
          pup_env_detail = "#{pup_env_code} status"
          sec_env_detail = "#{sec_env_code} status"
          allow(@env_helper).to receive(:puppet_env_status).and_return([pup_env_code, pup_env_detail])
          allow(@env_helper).to receive(:secondary_env_status).and_return([sec_env_code, sec_env_detail])

          status_detail = [pup_env_detail, sec_env_detail].join("\n")
          expect( @env_helper.env_status ).to eq([status_code, status_detail])
        end
      end
    end
  end

  describe '#puppet_env_status' do
    it 'returns :missing when the env does not exist' do
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)
      allow(@env_helper).to receive(:get_puppet_env_datadir).and_return(nil)

      result_code, result_details = @env_helper.puppet_env_status
      expect( result_code ).to eq :missing
      expect( result_details ).to eq "Puppet environment 'production' does not exist"
    end

    it 'returns :empty when the env contains no modules' do
      FileUtils.mkdir_p(@puppet_env_root_dir)
      FileUtils.cp_r(File.join(@puppet_env_files_dir, 'environments', 'simp'), @puppet_env_root_dir)
      File.rename(File.join(@puppet_env_root_dir, 'simp'), @puppet_env_dir)
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'modules'))
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)

      result_code, result_details = @env_helper.puppet_env_status
      expect( result_code ).to eq :empty
      expect( result_details ).to eq "Existing Puppet environment 'production' contains no modules"
    end

    # Mimics R10K failure in which you end up with an empty module dir
    it 'returns :empty when the env contains module dirs missing metadata.json files' do
      FileUtils.mkdir_p(@puppet_env_root_dir)
      FileUtils.cp_r(File.join(@puppet_env_files_dir, 'environments', 'simp'), @puppet_env_root_dir)
      File.rename(File.join(@puppet_env_root_dir, 'simp'), @puppet_env_dir)
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'modules'))
      FileUtils.mkdir(File.join@puppet_env_dir, 'modules', 'stdlib')
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)

      result_code, result_details = @env_helper.puppet_env_status
      expect( result_code ).to eq :empty
      expect( result_details ).to eq "Existing Puppet environment 'production' contains no modules"
    end

    it 'returns :invalid when the env contains module dirs but is missing stock SIMP datadir' do
      FileUtils.mkdir_p(@puppet_env_root_dir)
      FileUtils.cp_r(File.join(@puppet_env_files_dir, 'environments', 'simp'), @puppet_env_root_dir)
      File.rename(File.join(@puppet_env_root_dir, 'simp'), @puppet_env_dir)
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'modules'))
      module_dir = File.join@puppet_env_dir, 'modules', 'stdlib'
      FileUtils.mkdir(module_dir)
      FileUtils.touch(File.join(module_dir, 'metadata.json'))
      File.rename(File.join(@puppet_env_dir, 'data'), File.join(@puppet_env_dir, 'mydata'))
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)

      result_code, result_details = @env_helper.puppet_env_status
      expect( result_code ).to eq :invalid
      expect( result_details ).to eq "Existing Puppet environment 'production' at '#{@puppet_env_dir}' missing 'data' or 'hieradata' dir"
    end

    it 'returns :present when the env contains module dirs and stock SIMP datadir' do
      FileUtils.mkdir_p(@puppet_env_root_dir)
      FileUtils.cp_r(File.join(@puppet_env_files_dir, 'environments', 'simp'), @puppet_env_root_dir)
      File.rename(File.join(@puppet_env_root_dir, 'simp'), @puppet_env_dir)
      FileUtils.mkdir_p(File.join(@puppet_env_dir, 'modules'))
      module_dir = File.join@puppet_env_dir, 'modules', 'stdlib'
      FileUtils.mkdir(module_dir)
      FileUtils.touch(File.join(module_dir, 'metadata.json'))
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)

      result_code, result_details = @env_helper.puppet_env_status
      expect( result_code ).to eq :present
      expect( result_details ).to eq "Puppet environment 'production' exists with modules at '#{@puppet_env_dir}'"
    end
  end

  describe '#secondary_env_status' do
    it 'returns :missing when the env does not exist' do
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)
      allow(@env_helper).to receive(:get_puppet_env_datadir).and_return(@puppet_env_datadir)

      result_code, result_details = @env_helper.secondary_env_status
      expect( result_code ).to eq :missing
      expect( result_details ).to eq "Secondary environment 'production' does not exist at '#{@secondary_env_dir}'"
    end

    it 'returns :present when the env and cert generator exist' do
      fake_ca_dir = File.join(@secondary_env_dir, 'FakeCA')
      FileUtils.mkdir_p(fake_ca_dir)
      # in case we do not have exec privileges in /tmp, use a link instead
      FileUtils.ln_s(
        File.join(@sec_env_files_dir, 'FakeCA', Simp::Cli::CERTIFICATE_GENERATOR),
        File.join(fake_ca_dir,  Simp::Cli::CERTIFICATE_GENERATOR)
      )

      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)
      allow(@env_helper).to receive(:get_puppet_env_datadir).and_return(@puppet_env_datadir)

      result_code, result_details = @env_helper.secondary_env_status
      expect( result_code ).to eq :present
      expect( result_details ).to eq "Secondary environment 'production' exists at '#{@secondary_env_dir}'"
    end

    it 'returns :invalid when the env exists but cert generator does not exist' do
      FileUtils.mkdir_p(@secondary_env_dir)
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)
      allow(@env_helper).to receive(:get_puppet_env_datadir).and_return(@puppet_env_datadir)

      result_code, result_details = @env_helper.secondary_env_status
      expect( result_code ).to eq :invalid
      cert_gen = File.join(@secondary_env_dir, 'FakeCA', Simp::Cli::CERTIFICATE_GENERATOR)
      expect( result_details ).to eq "Existing secondary environment 'production' missing executable #{cert_gen}"
    end

    it 'returns :invalid when the env exists but cert generator is not executable' do
      fake_ca_dir = File.join(@secondary_env_dir, 'FakeCA')
      FileUtils.mkdir_p(fake_ca_dir)
      FileUtils.touch(File.join(fake_ca_dir,  Simp::Cli::CERTIFICATE_GENERATOR))
      allow(@env_helper).to receive(:get_system_puppet_info).and_return(@system_puppet_info)
      allow(@env_helper).to receive(:get_puppet_env_datadir).and_return(@puppet_env_datadir)

      result_code, result_details = @env_helper.secondary_env_status
      expect( result_code ).to eq :invalid
      cert_gen = File.join(@secondary_env_dir, 'FakeCA', Simp::Cli::CERTIFICATE_GENERATOR)
      expect( result_details ).to eq "Existing secondary environment 'production' missing executable #{cert_gen}"
    end
  end

  # Need to use Object.send() to test private method
  describe '#get_puppet_env_datadir' do

    before(:each) do
      FileUtils.mkdir_p(@puppet_env_root_dir)
    end

    it 'returns nil when neither hieradata/ nor data/ exist' do
      FileUtils.mkdir_p(@puppet_env_dir)
      expect( @env_helper.send(:get_puppet_env_datadir, @puppet_env_dir) ).to be_nil
    end

    it 'returns Hiera 5 environment data dir when simp env is configured for Hiera 5' do
      FileUtils.cp_r(File.join(@puppet_env_files_dir, 'environments', 'simp'), @puppet_env_root_dir)
      File.rename(File.join(@puppet_env_root_dir, 'simp'), @puppet_env_dir)
      expect( @env_helper.send(:get_puppet_env_datadir, @puppet_env_dir) ).to eq File.join(@puppet_env_dir, 'data')
    end

    it 'returns Hiera 3 environment data dir when simp env is configured for Hiera 3' do
      FileUtils.cp_r(File.join(@puppet_env_files_dir, 'environments', 'simp_hiera3'), @puppet_env_root_dir)
      File.rename(File.join(@puppet_env_root_dir, 'simp_hiera3'), @puppet_env_dir)
      expect( @env_helper.send(:get_puppet_env_datadir, @puppet_env_dir) ).to eq File.join(@puppet_env_dir, 'hieradata')
    end

    it 'returns nil when an env-specific hieradata file exists, but the expected data dir does not' do
      FileUtils.cp_r(File.join(@puppet_env_files_dir, 'environments', 'simp'), @puppet_env_root_dir)
      File.rename(File.join(@puppet_env_root_dir, 'simp'), @puppet_env_dir)
      FileUtils.mv(File.join(@puppet_env_dir, 'data'), File.join(@puppet_env_dir, 'hieradata'))
      expect( @env_helper.send(:get_puppet_env_datadir, @puppet_env_dir) ).to be_nil
    end
  end

end
