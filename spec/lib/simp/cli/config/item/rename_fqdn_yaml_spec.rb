require 'simp/cli/config/item/rename_fqdn_yaml'
require 'simp/cli/config/item/hostname'
require 'rspec/its'
require_relative 'spec_helper'

describe Simp::Cli::Config::Item::RenameFqdnYaml do
  before :all do
    @ci        = Simp::Cli::Config::Item::RenameFqdnYaml.new
    @ci.silent = true   # turn off command line summary on stdout
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      @ci.file = 'puppet.your.domain.yaml'
      expect(@ci.apply_summary).to eq "Rename of puppet.your.domain.yaml template to <host>.yaml unattempted"
    end
  end

  describe "#apply" do
    before :each do
      @fqdn            = 'hostname.domain.tld'
      @files_dir       = File.expand_path( 'files', File.dirname( __FILE__ ) )
      @tmp_dir         = Dir.mktmpdir( File.basename(__FILE__) )
      @file            = File.join( @files_dir,'puppet.your.domain.yaml')
      @template_file   = File.join( @tmp_dir, 'puppet.your.domain.yaml' )
      @ci.file         = @template_file

      item             = Simp::Cli::Config::Item::Hostname.new
      item.value       = @fqdn
      @ci.config_items[item.key] = item
      @new_file        = File.join( @tmp_dir, "#{@fqdn}.yaml" )
    end

    after :each do
      FileUtils.chmod_R 0777, @tmp_dir
      FileUtils.remove_entry_secure @tmp_dir
    end

    it "renames template when <host>.yaml does not exist" do
      FileUtils.cp(@file, @template_file)
      @ci.apply
      expect(@ci.applied_status).to eq :succeeded
      expect(@ci.apply_summary).to eq(
        'Rename of puppet.your.domain.yaml template to hostname.domain.tld.yaml succeeded')
      expect( File ).to exist( @new_file )
      expect( File ).not_to exist( @template_file )
    end

    it "removes template when <host>.yaml does exist and is identical" do
      FileUtils.cp(@file, @template_file)
      FileUtils.cp(@file, @new_file)
      @ci.apply
      expect(@ci.applied_status).to eq :succeeded
      expect(@ci.apply_summary).to eq(
        'Rename of puppet.your.domain.yaml template to hostname.domain.tld.yaml succeeded')
      expect( File ).not_to exist( @template_file )
      expect( File ).to exist( @new_file )
    end

    it "does not rename template when <host>.yaml does exist and is different" do
      FileUtils.cp(@file, @template_file)
      FileUtils.cp(@file, @new_file)
      File.open(@new_file, 'w') { |file|  file.puts("#  make sure files differ") }
      @ci.apply
      expect(@ci.applied_status).to eq :deferred
      expect(@ci.apply_summary).to eq(
        "Rename of puppet.your.domain.yaml template to hostname.domain.tld.yaml" +
        " deferred:\n\tManual merging of puppet.your.domain.yaml into" +
        " hostname.domain.tld.yaml may be required")
      expect( File ).to exist( @template_file )
      expect( File ).to exist( @new_file )
      expect( FileUtils.compare_file(@template_file, @new_file)).to be false
    end

    it "does nothing when template does not exist but <host>.yaml does exist" do
      FileUtils.cp(@file, @new_file)
      @ci.apply
      expect(@ci.applied_status).to eq :unnecessary
      expect(@ci.apply_summary).to eq(
        "Rename of puppet.your.domain.yaml template to hostname.domain.tld.yaml" +
        " unnecessary:\n\tTemplate already moved to hostname.domain.tld.yaml")
    end

    it "fails when both template and <host>.yaml do not exist" do
      @ci.apply
      expect(@ci.applied_status).to eq :failed
    end

    it "raises exception when 'hostname' config does not exist" do
      @ci.config_items.delete('hostname')
      expect{ @ci.apply }.to raise_error( KeyError, 'key not found: "hostname"' )
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end

