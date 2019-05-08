require 'simp/cli/config/items/action/update_os_yum_repositories_action'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::UpdateOsYumRepositoriesAction do
  context "in a SIMP directory structure" do
    before :each do
      @files_dir   = File.expand_path( 'files', File.dirname( __FILE__ ) )
      @tmp_dir     = Dir.mktmpdir( File.basename( __FILE__ ) )
      @tmp_yum_dir = File.expand_path( 'yum',   @tmp_dir )
      @tmp_repos_d = File.expand_path( 'yum.repos.d', @tmp_dir )

      FileUtils.mkdir_p   @tmp_yum_dir
      FileUtils.mkdir_p   @tmp_repos_d

      @ci             = Simp::Cli::Config::Item::UpdateOsYumRepositoriesAction.new
      @ci.www_yum_dir = @tmp_yum_dir
      @ci.yum_repos_d = @tmp_repos_d
      @ci.silent      =  true  # comment out this line to see log output
    end

    describe '#apply' do
      before :each do
        Facter.reset  # make sure other test's facts don't affect these tests
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

      # TODO:  Test with acceptance test
      skip 'disables existing CentOS repos'

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

      @ci             = Simp::Cli::Config::Item::UpdateOsYumRepositoriesAction.new
      @ci.www_yum_dir = @tmp_yum_dir
      @ci.yum_repos_d = @tmp_repos_d
      @ci.silent      =  true  # comment out this line to see log output
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
      end

      it "fails when yum OS/REL/ARCH dir does not exist" do
        @ci.apply
        expect( @ci.applied_status ).to eq(:failed)
        expect( @ci.apply_summary ).to eq 'Setup of local system (OS) YUM repositories for SIMP failed'
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
        expect( @ci.apply_summary ).to eq 'Setup of local system (OS) YUM repositories for SIMP failed'
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
      ci = Simp::Cli::Config::Item::UpdateOsYumRepositoriesAction.new
      expect( ci.apply_summary ).to eq 'Setup of local system (OS) YUM repositories for SIMP unattempted'
    end
  end

end
