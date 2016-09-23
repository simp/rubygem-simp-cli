require 'simp/cli/config/item/yum_repositories'
require 'simp/cli/config/item/hostname'
require 'simp/cli/config/item/is_master_yum_server'
require 'rspec/its'
require 'tmpdir'
require_relative 'spec_helper'

describe Simp::Cli::Config::Item::YumRepositories do
  context "in a SIMP directory structure" do
    before :each do
      @files_dir   = File.expand_path( 'files', File.dirname( __FILE__ ) )
      @tmp_dir     = Dir.mktmpdir( File.basename( __FILE__ ) )
      @tmp_yum_dir = File.expand_path( 'yum',   @tmp_dir )
      @tmp_repos_d = File.expand_path( 'yum.repos.d', @tmp_dir )
      yaml_file       = File.join( @files_dir, 'puppet.your.domain.yaml' )
      @fqdn            = 'hostname.domain.tld'
      @tmp_yaml_file   = File.join( @tmp_dir,   "#{@fqdn}.yaml" )
      FileUtils.cp( yaml_file, @tmp_yaml_file )

      FileUtils.mkdir_p   @tmp_yum_dir
      FileUtils.mkdir_p   @tmp_repos_d

      @ci             = Simp::Cli::Config::Item::YumRepositories.new
      @ci.www_yum_dir = @tmp_yum_dir
      @ci.yum_repos_d = @tmp_repos_d
      @ci.dir         = @tmp_dir
      @ci.silent      =  true
      item             = Simp::Cli::Config::Item::Hostname.new
      item.value       = @fqdn
      @ci.config_items[item.key] = item
    end

    describe '#apply' do
      before :each do
        @fake_facts = {
          'operatingsystem'        => 'TrevOS',
          'operatingsystemrelease' => '9.9',
          'architecture'           => 'ia64'
        }
        @fake_facts.each{ |k,v| ENV["FACTER_#{k}"] = v }
        @yum_dist_dir = File.join(
                                     @tmp_yum_dir,
                                     @fake_facts['operatingsystem'],
                                     @fake_facts['operatingsystemrelease'],
                                     @fake_facts['architecture']
                                   )
        FileUtils.remove_entry_secure @yum_dist_dir if File.exists? @yum_dist_dir
        FileUtils.mkdir_p @yum_dist_dir
        item             = Simp::Cli::Config::Item::IsMasterYumServer.new
        item.value       = true
        @ci.config_items[item.key] = item
      end

      it 'creates the yum Updates directory and generates the yum Updates repo metadata' do
        @ci.apply
        expect( File.directory?( File.join( @yum_dist_dir, 'Updates') ) ).to eq( true )

        file =  File.join( @yum_dist_dir, 'Updates', 'repodata', 'repomd.xml' )
        if (value = ENV['SIMP_SKIP_NON_SIMPOS_TESTS'])
          skip "skipping because env var SIMP_SKIP_NON_SIMPOS_TESTS is set to #{value}"
        else
          expect( File.exists?( file )).to eq( true )
          expect( File.size?( file ) ).to  be_truthy
        end
      end

      context("when is master yum server") do
        it 'enables simp::yum::enable_simp_repos in hiera' do
          @ci.apply
          lines = File.readlines( @tmp_yaml_file ).join( "\n" )
          expect( lines ).to match(%r{^simp::yum::enable_simp_repos\s*:\s*true})
        end

        it 'reports successful operations' do
          if (value = ENV['SIMP_SKIP_NON_SIMPOS_TESTS'])
            skip "skipping because env var SIMP_SKIP_NON_SIMPOS_TESTS is set to #{value}"
          else
            @ci.apply
            expect( @ci.applied_status ).to eq(:succeeded)

            expected = "Configuration of YUM Update repo at #{@yum_dist_dir} succeeded"
            expect( @ci.apply_summary.split("\n")[0] ).to eq(expected)

            expected = "Update to simp::yum::enable_simp_repos in hostname.domain.tld.yaml succeeded"
            expect( @ci.apply_summary.split("\n")[1] ).to eq(expected)
          end
        end
      end

      context("when is not a master yum server") do
        before :each do
          item             = Simp::Cli::Config::Item::IsMasterYumServer.new
          item.value       = false
          @ci.config_items[item.key] = item
        end

        it 'does not enable simp::yum::enable_simp_repos in hiera' do
          result = @ci.apply
          lines = File.readlines( @tmp_yaml_file ).join( "\n" )
          expect( lines ).to_not match(%r{^simp::yum::enable_simp_repos\s*:\s*true})
        end

        it 'reports successful operations' do
          if (value = ENV['SIMP_SKIP_NON_SIMPOS_TESTS'])
            skip "skipping because env var SIMP_SKIP_NON_SIMPOS_TESTS is set to #{value}"
          else
            @ci.apply
            expect( @ci.applied_status ).to eq(:succeeded)
            expected = "Configuration of YUM Update repo at #{@yum_dist_dir} succeeded"
            expect( @ci.apply_summary.split("\n")[0] ).to eq(expected)
          end
        end
      end

      it_behaves_like "an Item that doesn't output YAML"
      it_behaves_like 'a child of Simp::Cli::Config::Item'

      after :each do
        @fake_facts.each{ |k,v| ENV.delete "FACTER_#{k}" }
        FileUtils.remove_entry_secure @tmp_dir
      end
    end
  end

  context "not in SIMP directory structure" do
    before :each do
      @tmp_dir     = Dir.mktmpdir( File.basename( __FILE__ ) )
      @tmp_yum_dir = File.expand_path( 'yum',   @tmp_dir )
      @tmp_repos_d = File.expand_path( 'yum.repos.d', @tmp_dir )
      FileUtils.mkdir_p @tmp_repos_d
      @fqdn            = 'hostname.domain.tld'
      @tmp_yaml_file   = File.join( @tmp_dir,   "#{@fqdn}.yaml" )
      FileUtils.touch @tmp_yaml_file

      @ci             = Simp::Cli::Config::Item::YumRepositories.new
      @ci.www_yum_dir = @tmp_yum_dir
      @ci.yum_repos_d = @tmp_repos_d
      @ci.dir         = @tmp_dir
      @ci.silent      =  true
      item             = Simp::Cli::Config::Item::Hostname.new
      item.value       = @fqdn
      @ci.config_items[item.key] = item
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end

    describe '#apply' do
      before :each do
        @fake_facts = {
          'operatingsystem'        => 'TrevOS',
          'operatingsystemrelease' => '9.9',
          'architecture'           => 'ia64'
        }
        @fake_facts.each{ |k,v| ENV["FACTER_#{k}"] = v }
        @yum_dist_dir = File.join(
                                     @tmp_yum_dir,
                                     @fake_facts['operatingsystem'],
                                     @fake_facts['operatingsystemrelease'],
                                     @fake_facts['architecture']
                                   )
        item             = Simp::Cli::Config::Item::IsMasterYumServer.new
        item.value       = true
        @ci.config_items[item.key] = item
      end

      it "fails when yum OS/REL/ARCH dir does not exist" do
        @ci.apply
        expect( @ci.applied_status ).to eq(:failed)
        expected = "Configuration of YUM Update repo at #{@yum_dist_dir} failed"
        expect( @ci.apply_summary.split("\n")[0] ).to eq(expected)

        expected = "Update to simp::yum::enable_simp_repos in hostname.domain.tld.yaml succeeded"
        expect( @ci.apply_summary.split("\n")[1] ).to eq(expected)
      end

      it "fails when yum OS/REL/ARCH dir cannot be accessed" do
        FileUtils.mkdir_p @yum_dist_dir
        FileUtils.chmod 0444, @yum_dist_dir
        @ci.apply
        expect( @ci.applied_status ).to eq(:failed)
      end

      it "fails when yum Updates dir cannot be created due to permissions" do
        FileUtils.mkdir_p @yum_dist_dir
        FileUtils.chmod 0555, @yum_dist_dir
        @ci.apply
        expect( @ci.applied_status ).to eq(:failed)
      end

      it "fails when yum Updates dir cannot be created because a file named Updates exists" do
        FileUtils.mkdir_p @yum_dist_dir
        FileUtils.touch File.join(@yum_dist_dir, 'Updates')
        @ci.apply
        expect( @ci.applied_status ).to eq(:failed)
      end

      it "fails when yum Updates dir cannot be accessed" do
        updates_dir = File.join(@yum_dist_dir, 'Updates')
        FileUtils.mkdir_p updates_dir
        FileUtils.chmod 0000, updates_dir
        @ci.apply
        expect( @ci.applied_status ).to eq(:failed)
      end

      it "fails when yum.repos.d does not exist" do
        FileUtils.mkdir_p @yum_dist_dir
        FileUtils.rm_rf @tmp_repos_d
        @ci.apply
        expect( @ci.applied_status ).to eq(:failed)
        expect( @ci.apply_summary ). to match(
          /Update to simp::yum::enable_simp_repos in hostname.domain.tld.yaml failed/m)
      end

      it "fails when yum.repos.d cannot be accessed" do
        FileUtils.mkdir_p @yum_dist_dir
        FileUtils.chmod 0000, @tmp_repos_d
        @ci.apply
        expect( @ci.applied_status ).to eq(:failed)
      end

      it "fails when yum.repos.d is not a directory" do
        FileUtils.mkdir_p @yum_dist_dir
        FileUtils.rm_rf @tmp_repos_d
        FileUtils.touch File.join(@tmp_dir, 'yum.repos.d')
        @ci.apply
        expect( @ci.applied_status ).to eq(:failed)
      end

      it "fails when puppet.your.domain.yaml does not exist" do
        FileUtils.mkdir_p @yum_dist_dir
        FileUtils.rm_rf @tmp_yaml_file
        @ci.apply
        expect( @ci.applied_status ).to eq(:failed)
      end

      after :each do
        @fake_facts.each{ |k,v| ENV.delete "FACTER_#{k}" }
        if Dir.exist?(@yum_dist_dir)
          # On some systems, not being able to access the directory causes
          # FileUtils.chmod_R to not be able to set the permissions properly on
          # mode 0000 subdirectories. This subsequently causes
          # remove_entry_secure to fail.

          if Dir.exist?(@tmp_repos_d)
            FileUtils.chmod(0777, @tmp_repos_d)
          end

          FileUtils.chmod_R(0777, @yum_dist_dir)
          FileUtils.remove_entry_secure(@yum_dist_dir)
        end
      end
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      ci = Simp::Cli::Config::Item::YumRepositories.new
      expect(ci.apply_summary).to eq 'YUM Update repo configuration and update to simp::yum::enable_simp_repos in <host>.yaml unattempted'
    end
  end

end
