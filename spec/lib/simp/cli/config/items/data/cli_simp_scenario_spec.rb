require 'simp/cli/config/items/data/cli_simp_scenario'
require 'fileutils'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliSimpScenario do
  before :each do
    env_files_dir = File.expand_path('../../../commands/files', __dir__)

    @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
    FileUtils.cp_r(File.join(env_files_dir, 'environments', 'simp'), @tmp_dir)
    @puppet_env_dir = File.join(@tmp_dir, 'simp')

    puppet_env_info = {
      :puppet_env_dir => @puppet_env_dir
    }

    @ci = Simp::Cli::Config::Item::CliSimpScenario.new(puppet_env_info)
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  context '#recommended_value' do
    it "returns 'simp'" do
      expect( @ci.recommended_value ).to eq('simp')
    end
  end

  context '#os_value' do

    it 'returns value in site.pp' do
      expect( @ci.os_value ).to eq('simp')
    end

    it 'returns nil when site.pp does not exist' do
      FileUtils.rm_rf(File.join(@puppet_env_dir, 'manifests'))
      expect( @ci.os_value ).to eq nil
    end

  end

  context '#to_yaml_s custom behavior' do
    it 'never returns auto warning message' do
      auto_warning = @ci.auto_warning
      expect( @ci.to_yaml_s(false) ).to_not match(/#{auto_warning}/)
      expect( @ci.to_yaml_s(true) ).to_not match(/#{auto_warning}/)
    end
  end

  context '#validate' do
    it "validates 'simp'" do
      expect( @ci.validate('simp') ).to eq true
    end

    it "validates 'simp_lite'" do
      expect( @ci.validate('simp_lite') ).to eq true
    end

    it "validates 'poss'" do
      expect( @ci.validate('poss') ).to eq true
    end

    it 'rejects invalid scenario names' do
      expect( @ci.validate('pss') ).to eq false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
