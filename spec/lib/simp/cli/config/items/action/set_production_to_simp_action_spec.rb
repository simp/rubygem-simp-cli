require 'simp/cli/config/items/action/set_production_to_simp_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetProductionToSimpAction do
  before :each do
    @ci            = Simp::Cli::Config::Item::SetProductionToSimpAction.new
#    @ci.silent     = true # comment out this line if you want to see the messages generated
    @ci.start_time = Time.new(2017, 1, 13, 11, 42, 3)
  end

  describe '#apply' do
    before :each do
      @tmp_dir                   = Dir.mktmpdir( File.basename( __FILE__ ) )
      @primary_env_path          = File.join(@tmp_dir, 'primary', 'environments')
      @secondary_env_path        = File.join(@tmp_dir, 'secondary', 'environments')
      @primary_production_path   = File.join(@primary_env_path, 'production')
      @secondary_production_path = File.join(@secondary_env_path, 'production')
      @primary_simp_path         = File.join(@primary_env_path, 'simp')
      @secondary_simp_path       = File.join(@secondary_env_path, 'simp')
      FileUtils.mkdir_p(@primary_simp_path)
      FileUtils.mkdir_p(@secondary_simp_path)
      @ci.primary_env_path       = @primary_env_path
      @ci.secondary_env_path     = @secondary_env_path
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end

    context 'neither primary nor secondary production environments exist' do
      it "creates links to 'simp' in both environments" do
        @ci.apply
        expect( File.readlink(@primary_production_path) ).to eq 'simp'
        expect( File.readlink(@secondary_production_path) ).to eq 'simp'
        expect( @ci.applied_status ).to eq :succeeded
      end
    end

    context 'when primary production environment is a symlink' do
      it "moves the link to 'simp'" do
        FileUtils.mkdir_p(@secondary_production_path)
        other_env = File.join(@primary_env_path, 'other_production')
        FileUtils.mkdir_p(other_env)
        FileUtils.touch(File.join(other_env,'other_env_file'))
        File.symlink(other_env, @primary_production_path)

        @ci.apply
        expect( File.readlink(@primary_production_path) ).to eq 'simp'
        expect( File.exist?(other_env) ).to eq true
        expect( @ci.applied_status ).to eq :succeeded
      end
    end

    context 'when primary production environment is a directory ' do
      it 'backs up the previous production environment and creates a link' do
        FileUtils.mkdir_p(@secondary_production_path)
        FileUtils.mkdir_p(@primary_production_path)
        FileUtils.touch(File.join(@primary_production_path,'prev_env_file'))
        @ci.apply
        expect( File.readlink(@primary_production_path) ).to eq 'simp'
        backup_parent = "#{@primary_env_path}.bak"
        expect( Dir.exist?(backup_parent) ).to eq true
        backup_dir = File.join(backup_parent, "#{File.basename(@primary_production_path)}.20170113T114203")
        expect( Dir.exist?(backup_dir) ).to eq true
        expect( File.exist?(File.join(backup_dir, 'prev_env_file')) ).to eq true
        expect( @ci.applied_status ).to eq :succeeded
      end
    end

    context 'when secondary production environment exists' do
      it 'does nothing to secondary production environment' do
        FileUtils.mkdir_p(@secondary_production_path)
        FileUtils.touch(File.join(@secondary_production_path, 'production_file'))
        @ci.apply
        expect( File.exist?(@secondary_production_path) ).to eq true
        expect( File.exist?(File.join(@secondary_production_path,'production_file')) ).to eq true
        expect( @ci.applied_status ).to eq :succeeded
      end
    end

    context 'when primary environments path does not exist' do
      it 'reports failed status' do
        FileUtils.rm_rf(@primary_env_path)
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end

    context 'when primary simp environment does not exist' do
      it 'reports failed status' do
        FileUtils.rmdir(@primary_simp_path)
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end

    context 'when secondary simp environment does not exist' do
      it 'reports failed status' do
        FileUtils.rmdir(@secondary_simp_path)
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq "Setting 'simp' to the Puppet default environment unattempted"
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
