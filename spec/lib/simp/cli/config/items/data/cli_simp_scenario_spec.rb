require 'simp/cli/config/items/data/cli_simp_scenario'
require 'fileutils'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliSimpScenario do
  before :each do
    @ci = Simp::Cli::Config::Item::CliSimpScenario.new
  end

  context '#recommended_value' do
    it "returns 'simp'" do
      expect( @ci.recommended_value ).to eq('simp')
    end
  end

  context '#os_value' do
    let(:env_files_dir) { File.join(File.dirname(__FILE__), '..', '..', '..', 'commands', 'files') }

    before :each do
      @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )

      allow(::Utils).to receive(:puppet_info).and_return( {
        :config => {
          'codedir' => @tmp_dir,
          'confdir' => @tmp_dir
        },
        :environment_path => File.join(@tmp_dir, 'environments'),
        :simp_environment_path => File.join(@tmp_dir, 'environments', 'simp'),
        :fake_ca_path => File.join(@tmp_dir, 'environments', 'simp', 'FakeCA')
      } )
      FileUtils.cp_r(File.join(env_files_dir, 'environments'), @tmp_dir)
    end

    it 'returns value in site.pp' do
      expect( @ci.os_value ).to eq('poss')
    end

    it 'returns nil when site.pp does not exist' do
      FileUtils.rm_rf(File.join(@tmp_dir, 'environments'))
      expect( @ci.os_value ).to eq nil
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
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

    it "rejects invalid scenario names" do
      expect( @ci.validate('pss') ).to eq false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
