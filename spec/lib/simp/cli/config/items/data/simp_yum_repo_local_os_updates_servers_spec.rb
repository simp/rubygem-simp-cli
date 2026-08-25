# frozen_string_literal: true

require 'simp/cli/config/items/data/simp_yum_repo_local_os_updates_servers'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpYumRepoLocalOsUpdatesServers do
  before :each do
    @ci = described_class.new
  end

  describe '#recommended_value' do
    it 'recommends puppet master when this server has local repos installed by ISO' do
      item = Simp::Cli::Config::Item::CliHasSimpFilesystemYumRepo.new
      item.value = true
      @ci.config_items[item.key] = item

      expect(@ci.recommended_value).to eq ["%{hiera('simp_options::puppet::server')}"]
    end

    it "recommends 'FIXME' when this server does not have local repos installed by ISO" do
      item = Simp::Cli::Config::Item::CliHasSimpFilesystemYumRepo.new
      item.value = false
      @ci.config_items[item.key] = item

      expect(@ci.recommended_value).to eq ['FIXME']
    end
  end

  describe '#validate' do
    it 'validates array with good hosts' do
      expect(@ci.validate(['yum'])).to be true
      expect(@ci.validate(['yum-server'])).to be true
      expect(@ci.validate(['yum.yummityyum.org'])).to be true
      expect(@ci.validate(['192.168.1.1'])).to be true
      expect(@ci.validate(['192.168.1.1'])).to be true
      expect(@ci.validate(["%{hiera('puppet::server')}"])).to be true
      expect(@ci.validate(['%{::domain}'])).to be true

      # yum_servers is not allowed to be empty
      expect(@ci.validate(nil)).to be false
      expect(@ci.validate('   ')).to be false
      expect(@ci.validate('')).to be false
      expect(@ci.validate([])).to be false
    end

    it "doesn't validate array with bad hosts" do
      expect(@ci.validate(0)).to be false
      expect(@ci.validate(false)).to be false
      expect(@ci.validate([nil])).to be false
      expect(@ci.validate(['yum-'])).to be false
      expect(@ci.validate(['-yum'])).to be false
      expect(@ci.validate(['yum.yummityyum.org-'])).to be false
      expect(@ci.validate(['.yum.yummityyum.org'])).to be false
      expect(@ci.validate(["%[hiera('puppet::server')]"])).to be false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
