require 'simp/cli/config/items/data/cli_has_simp_filesystem_yum_repo'
require 'fileutils'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliHasSimpFilesystemYumRepo do
  before :each do
    @ci = Simp::Cli::Config::Item::CliHasSimpFilesystemYumRepo.new
  end

  context '#recommended_value' do
    before :each do
      @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
      @tmp_yum_repo_dir = File.expand_path( 'yum.repos.d',   @tmp_dir )
      FileUtils.mkdir_p(@tmp_yum_repo_dir)
      @local_repo_file = File.join(@tmp_yum_repo_dir, 'simp_filesystem.repo')
      @ci.local_repo = @local_repo_file
    end

    context 'when system YUM repo exists' do
      it "returns 'yes'" do
        FileUtils.touch(@local_repo_file)
        expect( @ci.recommended_value ).to eq('yes')
      end
    end

    context 'when system YUM repo does not exist' do
      it "returns 'no'" do
        expect( @ci.recommended_value ).to eq('no')
      end
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
