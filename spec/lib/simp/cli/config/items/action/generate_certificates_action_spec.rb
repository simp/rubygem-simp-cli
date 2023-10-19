require 'simp/cli/config/items/action/generate_certificates_action'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::GenerateCertificatesAction do
  before :each do
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )

    @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__))
    @secondary_env = File.join( @tmp_dir, 'simp', 'environments', 'production' )

    @tmp_dirs = {
      :keydist => File.join( @secondary_env, 'site_files', 'pki_files', 'files', 'keydist' ),
      :fake_ca => File.join( @secondary_env, 'FakeCA' ),
    }

    FileUtils.mkdir_p @tmp_dirs.values
    src_dir   = File.join(@files_dir, 'FakeCA')
    FileUtils.cp( File.join(src_dir, 'cacertkey'), @tmp_dirs[:fake_ca] )
    # in case we do not have exec privileges in /tmp, use a link instead
    FileUtils.ln_s( File.join(src_dir, 'gencerts_nopass.sh'),
      File.join(@tmp_dirs[:fake_ca], 'gencerts_nopass.sh') )

    @puppet_env_info = {
      :puppet_config     => { 'modulepath' => '/does/not/matter' },
      :puppet_group      => `groups`.split[0],
      :secondary_env_dir => @secondary_env
    }

    @ci = Simp::Cli::Config::Item::GenerateCertificatesAction.new(@puppet_env_info)
    @ci.silent = true
    @fqdn  = 'puppet.testing.fqdn'
    item = Simp::Cli::Config::Item::CliNetworkHostname.new(@puppet_env_info)
    item.value = @fqdn
    @ci.config_items[ item.key ] = item
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
    ENV.delete 'SIMP_CLI_CERTIFICATES_FAIL'
  end

  describe '#apply' do
    context 'when keydist directory exists' do
      context 'when cert generation is required' do
        it 'generates certs and reports :succeeded status on success' do
          @ci.apply
          expect( @ci.applied_status ).to eq :succeeded
          dir = File.join( @tmp_dirs[:keydist], @fqdn )
          expect( File.exist? dir ).to be true
        end

        it 'reports :failed status on failure' do
          ENV['SIMP_CLI_CERTIFICATES_FAIL']='true'
          @ci.apply
          expect( @ci.applied_status ).to eq :failed
        end
      end

      context 'when cert generation is not required' do
        it 'reports :unnecessary status' do
          @ci.generate_certificates(@fqdn)
          dir = File.join( @tmp_dirs[:keydist], @fqdn )
          expect( File.exist? dir ).to be true
          @ci.apply
          expect( @ci.applied_status ).to eq :unnecessary
          expect(@ci.apply_summary).to match /Interim certificate generation for 'puppet.testing.fqdn' unnecessary:\n    Certificates already exist/m
        end
      end
    end

    context 'when keydist directory does not exist' do
      before :each do
        # pre-set the permissions on simp_env dirs, to verify they are set
        # appropriately
        @dirs_adjusted = [
          File.join( @tmp_dir, 'simp' ),
          File.join( @tmp_dir, 'simp', 'environments'),
          File.join( @tmp_dir, 'simp', 'environments', 'production'),
        ]
        @dirs_adjusted.each { |dir| FileUtils.chmod( 0700, dir ) }
        FileUtils.rm_rf( @tmp_dirs[:keydist] )
      end

      it 'creates dir tree, fixes perms, generates certs and reports :succeeded status on success' do
        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
        @dirs_adjusted.each { |dir| expect( File.stat( dir ).mode & 0777).to eq 0755 }

        # If the umask of process running the test is 0002, instead of
        # locked down 0022, the resulting mode will be 0770, not 0750.
        # This is because the operation applied is to remove access
        # to world and add read access to group:
        #    FileUtils.chmod_R('g+rX,o-rwx', site_files_dir)
        if (File.stat( File.join( @secondary_env, 'site_files') ).mode & 0070) == 0070
          expected_mode = 0770
        else
          expected_mode = 0750
        end

        [
          File.join( @secondary_env, 'site_files'),
          File.join( @secondary_env, 'site_files', 'pki_files'),
          File.join( @secondary_env, 'site_files', 'pki_files', 'files'),
          File.join( @secondary_env, 'site_files', 'pki_files', 'files', 'keydist'),
        ].each do |dir|
          expect( File.stat( dir ).mode & 0777).to eq expected_mode
        end

        dir = File.join( @tmp_dirs[:keydist], @fqdn )
        expect( File.exist? dir ).to be true
      end
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'Interim certificate generation for SIMP server unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end

