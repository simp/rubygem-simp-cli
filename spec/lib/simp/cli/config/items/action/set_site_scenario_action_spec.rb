require 'simp/cli/config/items/action/set_site_scenario_action'
require 'simp/cli/config/items/data/cli_simp_scenario'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetSiteScenarioAction do
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
  let(:env_files_dir) { File.join(File.dirname(__FILE__), '..', '..', '..', 'commands', 'files') }

  before :each do
    @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
    @site_pp = File.join(@tmp_dir, 'environments', 'simp', 'manifests', 'site.pp')

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

    @ci        = Simp::Cli::Config::Item::SetSiteScenarioAction.new
    @ci.silent = true
    @ci.start_time = Time.new(2017, 1, 13, 11, 42, 3)

    item       = Simp::Cli::Config::Item::CliSimpScenario.new
    item.value = 'simp'
    @ci.config_items[item.key] = item
  end

  context '#apply' do
    it 'backs up site.pp and replaces value in site.pp ' do
      @ci.apply
      expected = File.join(files_dir, 'site_with_simp_scenario.pp')
      expect( FileUtils.compare_file(expected, @site_pp)).to be true
      expect( @ci.applied_status ).to eq(:succeeded)
      backup_site_pp = "#{@site_pp}.20170113T114203"
      expect( File ).to exist( backup_site_pp )
      orig_site_pp = File.join(env_files_dir, 'environments', 'simp', 'manifests', 'site.pp')
      expect( FileUtils.compare_file(orig_site_pp, backup_site_pp)).to be true
    end

    it 'fails if site.pp is missing' do
      FileUtils.rm(@site_pp)
      @ci.apply
      expect( @ci.applied_status ).to eq(:failed)
    end

    it 'fails if $simp_scenario variable is missing from site.pp' do
      FileUtils.cp(File.join(files_dir, 'bad_site.pp'), @site_pp)
      @ci.apply
      expect( @ci.applied_status ).to eq(:failed)
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq "Setting of $simp_scenario in the simp environment's site.pp unattempted"
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
