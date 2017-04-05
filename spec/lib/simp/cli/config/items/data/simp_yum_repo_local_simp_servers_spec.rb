require 'simp/cli/config/items/data/simp_yum_repo_local_simp_servers'
require 'simp/cli/config/items/data/cli_has_simp_filesystem_yum_repo'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpYumRepoLocalSimpServers do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpYumRepoLocalSimpServers.new
  end

  describe "#recommended_value" do
    it "recommends puppet master when this server has local repos installed by ISO" do
      item = Simp::Cli::Config::Item::CliHasSimpFilesystemYumRepo.new
      item.value = true
      @ci.config_items[item.key] = item

      expect( @ci.recommended_value ).to eq ["%{hiera('simp_options::puppet::server')}"]
    end

    it "recommends 'FIXME' when this server does not have local repos installed by ISO" do
      item = Simp::Cli::Config::Item::CliHasSimpFilesystemYumRepo.new
      item.value = false
      @ci.config_items[item.key] = item

      expect( @ci.recommended_value ).to eq ['FIXME']
    end
  end

  describe "#validate" do
    it "validates array with good hosts" do
      expect( @ci.validate ['yum'] ).to eq true
      expect( @ci.validate ['yum-server'] ).to eq true
      expect( @ci.validate ['yum.yummityyum.org'] ).to eq true
      expect( @ci.validate ['192.168.1.1'] ).to eq true
      expect( @ci.validate ['192.168.1.1'] ).to eq true
      expect( @ci.validate ["%{hiera('puppet::server')}"] ).to eq true
      expect( @ci.validate ["%{::domain}"] ).to eq true

      # yum_servers is not allowed to be empty
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate '   ' ).to eq false
      expect( @ci.validate '' ).to eq false
      expect( @ci.validate [] ).to eq false
    end

    it "doesn't validate array with bad hosts" do
      expect( @ci.validate 0     ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate [nil] ).to eq false
      expect( @ci.validate ['yum-'] ).to eq false
      expect( @ci.validate ['-yum'] ).to eq false
      expect( @ci.validate ['yum.yummityyum.org.'] ).to eq false
      expect( @ci.validate ['.yum.yummityyum.org'] ).to eq false
      expect( @ci.validate ["%[hiera('puppet::server')]"] ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end

