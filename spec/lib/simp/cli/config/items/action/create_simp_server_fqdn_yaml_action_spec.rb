require 'simp/cli/config/items/action/create_simp_server_fqdn_yaml_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CreateSimpServerFqdnYamlAction do

  ['foss', 'pe'].each do |test_tgt|
    context "When running on #{test_tgt} puppet" do
      before :each do
        @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )

        @tmp_dir = Dir.mktmpdir( File.basename(__FILE__) )
        @hosts_dir = File.join(@tmp_dir, 'hosts')
        FileUtils.mkdir(@hosts_dir)

        @fqdn              = 'hostname.domain.tld'
        @alt_template_file = File.join( @tmp_dir, 'alt_puppet.your.domain.yaml' )

        @puppet_env_info = {
          :puppet_config      => { 'modulepath' => '/does/not/matter' },
          :puppet_group       => `groups`.split[0],
          :puppet_env_datadir => @tmp_dir
        }

        if test_tgt == 'pe'
          @yaml_target             = 'pe-puppet.your.domain.yaml'
          @puppet_env_info[:is_pe] = true
        else
          @yaml_target             = 'puppet.your.domain.yaml'
          @puppet_env_info[:is_pe] = false
        end

        @file                    = File.join( @files_dir, @yaml_target )
        @template_file           = File.join( @hosts_dir, @yaml_target )

        @ci            = Simp::Cli::Config::Item::CreateSimpServerFqdnYamlAction.new(@puppet_env_info)
        @ci.silent     = true
        @ci.start_time = Time.new(2017, 1, 13, 11, 42, 3)
      end

      after :each do
        FileUtils.chmod_R 0777, @tmp_dir
        FileUtils.remove_entry_secure @tmp_dir
      end

      describe '#apply_summary' do
        it 'reports unattempted status when #apply not called' do
          expect( @ci.apply_summary ).to eq 'Creation of SIMP server <host>.yaml unattempted'
        end
      end

      describe '#apply' do
        before :each do
          @ci.alt_file       = @alt_template_file

          item               = Simp::Cli::Config::Item::CliNetworkHostname.new(@puppet_env_info)
          item.value         = @fqdn
          @ci.config_items[item.key] = item
          @host_yaml         = File.join( @hosts_dir, "#{@fqdn}.yaml" )
          @backup_host_yaml  = "#{@host_yaml}.20170113T114203"
        end


        it 'renames template when <host>.yaml does not exist' do
          FileUtils.cp(@file, @template_file)
          @ci.apply
          expect( @ci.applied_status ).to eq :succeeded
          expect( @ci.apply_summary ).to eq(
            'Creation of hostname.domain.tld.yaml succeeded')
          expect( File ).to exist( @host_yaml )
          expect( File ).not_to exist( @template_file )
          expect( File ).not_to exist( @backup_host_yaml )
        end

        it 'removes template when <host>.yaml does exist and is identical' do
          FileUtils.cp(@file, @template_file)
          FileUtils.cp(@file, @host_yaml)
          @ci.apply
          expect( @ci.applied_status ).to eq :succeeded
          expect( @ci.apply_summary ).to eq(
            'Creation of hostname.domain.tld.yaml succeeded')
          expect( File ).to exist( @host_yaml )
          expect( File ).not_to exist( @template_file )
          expect( File ).not_to exist( @backup_host_yaml )
        end

        it 'backs up <host>.yaml, but does not rename template when <host>.yaml does exist and is different' do
          FileUtils.cp(@file, @template_file)
          FileUtils.cp(@file, @host_yaml)
          File.open(@host_yaml, 'a') { |file|  file.puts('#  make sure files differ') }
          @ci.apply
          expect( @ci.applied_status ).to eq :deferred
          expect( @ci.apply_summary ).to eq(
            'Creation of hostname.domain.tld.yaml' +
            " deferred:\n    Manual merging of #{@yaml_target} into" +
            ' pre-existing hostname.domain.tld.yaml may be required')
          expect( File ).to exist( @template_file )
          expect( File ).to exist( @host_yaml )
          expect( File ).to exist( @backup_host_yaml )
          expect( FileUtils.compare_file(@template_file, @host_yaml) ).to be false
          expect( FileUtils.compare_file(@host_yaml, @backup_host_yaml) ).to be true
        end

        it 'backs up <host>.yaml when template does not exist but <host>.yaml does exist' do
          FileUtils.cp(@file, @host_yaml)
          @ci.apply
          expect( @ci.applied_status ).to eq :unnecessary
          expect( @ci.apply_summary ).to eq(
            'Creation of hostname.domain.tld.yaml' +
            " unnecessary:\n    Template already moved to hostname.domain.tld.yaml")
          expect( File ).to exist( @backup_host_yaml )
          expect( FileUtils.compare_file(@host_yaml, @backup_host_yaml) ).to be true
        end

        it 'fails when template, alternative template and <host>.yaml do not exist' do
          @ci.apply
          expect( @ci.applied_status ).to eq :failed
        end

        it 'uses alternative template when template and <host>.yaml do not exist' do
          FileUtils.cp(@file, @alt_template_file)
          @ci.apply
          expect( @ci.applied_status ).to eq :succeeded
          expect( @ci.apply_summary ).to eq(
            'Creation of hostname.domain.tld.yaml succeeded')
          expect( File ).to exist( @alt_template_file )
          expect( File ).to exist( @host_yaml )
        end

        it "raises exception when 'cli::network::hostname' config does not exist" do
          @ci.config_items.delete('cli::network::hostname')
          expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
            'Internal error: Simp::Cli::Config::Item::CreateSimpServerFqdnYamlAction' +
            ' could not find cli::network::hostname' )
        end
      end

      it_behaves_like "an Item that doesn't output YAML"
      it_behaves_like 'a child of Simp::Cli::Config::Item'
    end
  end
end
