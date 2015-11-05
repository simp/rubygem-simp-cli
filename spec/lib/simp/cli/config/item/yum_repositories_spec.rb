require 'simp/cli/config/item/yum_repositories'
require 'simp/cli/config/item/is_master_yum_server'
require 'rspec/its'
require 'tmpdir'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::YumRepositories do
  context "in a SIMP directory structure"
    before :each do
      @files_dir   = File.expand_path( 'files', File.dirname( __FILE__ ) )
      @tmp_dir     = Dir.mktmpdir( File.basename( __FILE__ ) )
      @tmp_yum_dir = File.expand_path( 'yum',   @tmp_dir )
      @tmp_repos_d = File.expand_path( 'yum.repos.d', @tmp_dir )
      yaml_file       = File.join( @files_dir, 'puppet.your.domain.yaml' )
      @tmp_yaml_file   = File.join( @tmp_dir,   'puppet.your.domain.yaml__YumRepositories' )
      FileUtils.cp( yaml_file, @tmp_yaml_file )

      FileUtils.mkdir_p   @tmp_yum_dir
      FileUtils.mkdir_p   @tmp_repos_d

      @ci             = Simp::Cli::Config::Item::YumRepositories.new
      @ci.www_yum_dir = @tmp_yum_dir
      @ci.yum_repos_d = @tmp_repos_d
      @ci.yaml_file   = @tmp_yaml_file
      @ci.silent      =  true
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

      it 'creates the yum Updates directory' do
        result = @ci.apply
        expect( File.directory?( File.join( @yum_dist_dir, 'Updates') ) ).to eq( true )
      end

      it 'generates the yum Updates repo metadata' do
        result = @ci.apply
        file =  File.join( @yum_dist_dir, 'Updates', 'repodata', 'repomd.xml' )

        if (value = ENV['SIMP_SKIP_NON_SIMPOS_TESTS'])
          skip "skipping because env var SIMP_SKIP_NON_SIMPOS_TESTS is set to #{value}"
        else
          expect( File.exists?( file )).to eq( true )
          expect( File.size?( file ) ).to  be_truthy
        end
      end

      it 'enables simp::yum::enable_simp_repos in hiera' do
        result = @ci.apply
        lines = File.readlines( @tmp_yaml_file ).join( "\n" )
        expect( lines ).to match(%r{^simp::yum::enable_simp_repos\s*:\s*true})
      end

      it 'does not enable simp::yum::enable_simp_repos in hiera when IsMasterYumServer is false' do
        item             = Simp::Cli::Config::Item::IsMasterYumServer.new
        item.value       = false
        @ci.config_items[item.key] = item
        result = @ci.apply
        lines = File.readlines( @tmp_yaml_file ).join( "\n" )
        expect( lines ).to_not match(%r{^simp::yum::enable_simp_repos\s*:\s*true})
      end

      it 'returns true' do
        result = @ci.apply
        expect( result ).to eq true
      end

      it_behaves_like "an Item that doesn't output YAML"
      it_behaves_like 'a child of Simp::Cli::Config::Item'

      after :each do
        @fake_facts.each{ |k,v| ENV.delete "FACTER_#{k}" }
        FileUtils.remove_entry_secure @tmp_dir
      end
    end
end
