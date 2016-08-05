require 'simp/cli/config/item/add_ldap_to_hiera'
require 'simp/cli/config/item/hostname'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::AddLdapToHiera do
  before :each do
    @ci        = Simp::Cli::Config::Item::AddLdapToHiera.new
    @ci.silent = true
  end

  # describe "#contains_ldap?" do
  #   it 'decides to strip ::ldap and openldap:: classes' do
  #     expect(@ci.contains_ldap?('  - simp::ldap_server')).to be true
  #     expect(@ci.contains_ldap?(%q{  - 'simp::ldap_server'})).to be true
  #     expect(@ci.contains_ldap?('  - openldap')).to be true
  #     expect(@ci.contains_ldap?('  - openldap::server')).to be true
  #   end
  #
  #   it 'rejects false positives' do
  #     expect(@ci.contains_ldap?( '#  - simp::ldap_server')).to be false
  #     expect(@ci.contains_ldap?('  - randomldap::foo')).to be false
  #   end
  # end

  describe "#apply" do
    context "with a valid fqdn" do
      before :each do
        @fqdn            = 'hostname.domain.tld'
        @files_dir       = File.expand_path( 'files', File.dirname( __FILE__ ) )
        @tmp_dir         = Dir.mktmpdir( File.basename(__FILE__) )
        @file            = File.join( @files_dir,'puppet.your.domain.yaml')
        @tmp_file        = File.join( @tmp_dir, "#{@fqdn}.yaml" )
        @ci.dir          = @tmp_dir

        item             = Simp::Cli::Config::Item::Hostname.new
        item.value       = @fqdn
        @ci.config_items[item.key] = item
        @new_file        = File.join( @tmp_dir, "#{@fqdn}.yaml" )

        [@tmp_file, @new_file].each do |file|
          FileUtils.rm file if File.exists? file
        end

        FileUtils.mkdir_p   @tmp_dir
        FileUtils.copy_file @file, @tmp_file

        @result = @ci.apply
      end

      after :each do
        FileUtils.remove_entry_secure @tmp_dir
      end

      it "file will contain the simp::ldap_server class" do
        expect( File.open(@tmp_file).readlines.join("\n") ).to match(/simp::ldap_server/)
      end
    end
  end

  describe "#apply_summary" do
    it 'reports not attempted status when #safe_apply not called' do
      expect(@ci.apply_summary).to eq 'Addition of simp::ldap_server to <host>.yaml not attempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
