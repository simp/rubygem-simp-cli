require 'simp/cli/config/item/remove_ldap_from_hiera'
require 'simp/cli/config/item/hostname'
require_relative 'spec_helper'

describe Simp::Cli::Config::Item::RemoveLdapFromHiera do
  before :each do
    @ci        = Simp::Cli::Config::Item::RemoveLdapFromHiera.new
    @ci.silent = true
  end

  describe "#strip_line?" do
    it 'decides to strip ::ldap and openldap:: classes' do
      expect(@ci.strip_line?('  - simp::ldap_server')).to be true
      expect(@ci.strip_line?(%q{  - 'simp::ldap_server'})).to be true
      expect(@ci.strip_line?('  - openldap')).to be true
      expect(@ci.strip_line?('  - openldap::server')).to be true
    end

    it 'rejects false positives' do
      expect(@ci.strip_line?( '#  - simp::ldap_server')).to be false
      expect(@ci.strip_line?('  - randomldap::foo')).to be false
    end
  end

  describe "#apply" do
    context "with a valid fqdn" do
      before :each do
        @fqdn            = 'hostname.domain.tld'
        @files_dir       = File.expand_path( 'files', File.dirname( __FILE__ ) )
        @tmp_dir         = File.expand_path( 'tmp', File.dirname( __FILE__ ) )
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

      it "file won't have any lines containing ldap" do
        expect( File.open(@tmp_file).readlines.join("\n") ).not_to match(/ldap/)
      end
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'Removal of ldap classes from <host>.yaml unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
