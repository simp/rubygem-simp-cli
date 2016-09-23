require 'simp/cli/config/item/add_ldap_to_hiera'
require 'simp/cli/config/item/hostname'
require_relative 'spec_helper'

describe Simp::Cli::Config::Item::AddLdapToHiera do
  before :each do
    @ci        = Simp::Cli::Config::Item::AddLdapToHiera.new
    @ci.silent = true
  end

  describe "#contains_ldap?" do
    it 'decides to strip ::ldap and openldap:: classes' do
      expect(@ci.contains_ldap?('  - simp::ldap_server')).to be true
      expect(@ci.contains_ldap?(%q{  - 'simp::ldap_server'})).to be true
      expect(@ci.contains_ldap?('  - openldap')).to be true
      expect(@ci.contains_ldap?('  - openldap::server')).to be true
    end

    it 'rejects false positives' do
      expect(@ci.contains_ldap?( '#  - simp::ldap_server')).to be false
      expect(@ci.contains_ldap?('  - randomldap::foo')).to be false
    end
  end

  describe "#apply" do
    context "with a valid fqdn" do
      before :each do
        @fqdn            = 'hostname.domain.tld'
        @files_dir       = File.expand_path( 'files', File.dirname( __FILE__ ) )
        @tmp_dir         = Dir.mktmpdir( File.basename(__FILE__) )
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

        @ci.apply
      end

      after :each do
        FileUtils.remove_entry_secure @tmp_dir
      end

      it "adds simp::ldap_server class to <host>.yaml" do
        file = File.join( @files_dir,'puppet.your.domain.yaml')
        FileUtils.copy_file file, @tmp_file

        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_simp_ldap_server.yaml')

        expect( FileUtils.compare_file(expected, @tmp_file)).to be true
      end

      it "ensures only one simp::ldap_server class exists in <host>.yaml" do
        file = File.join( @files_dir,'host_with_simp_ldap_server.yaml')
        FileUtils.copy_file file, @tmp_file

        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
        expect( FileUtils.compare_file(file, @tmp_file)).to be true
      end

      it "fails when <host>.yaml does not exist" do
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'Addition of simp::ldap_server to <host>.yaml unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
