require 'simp/cli/config/items/action/check_remote_yum_config_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CheckRemoteYumConfigAction do
  before :each do
    @ci        = Simp::Cli::Config::Item::CheckRemoteYumConfigAction.new
    @ci.silent = true # uncomment out this line to see log message
  end

  describe "#apply" do
    before :each do
      @tmp_dir         = Dir.mktmpdir( File.basename(__FILE__) )
      @warning_file    = File.join(@tmp_dir, '.simp', 'simp_bootstrap_start_lock')
      @ci.warning_file = @warning_file
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end

    it "succeeds when both repos are found by repoquery" do
      allow(@ci).to receive(:execute).with('repoquery -i kernel | grep ^Repository').and_return(true)
      allow(@ci).to receive(:execute).with('repoquery -i simp | grep ^Repository').and_return(true)
      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
    end

    it "writes warning file when OS repo is not found by repoquery" do
      allow(@ci).to receive(:execute).with('repoquery -i kernel | grep ^Repository').and_return(false)
      allow(@ci).to receive(:execute).with('repoquery -i simp | grep ^Repository').and_return(true)
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
      expect( File.exist?(@warning_file) ).to eq true
      actual_message = IO.read(@warning_file)
      expect( actual_message).to eq @ci.warning_message
      expected_summary =
        "Your YUM configuration may be incomplete.  Verify you have set up system (OS)\n" +
        "    updates and SIMP repositories before running 'simp bootstrap'."
      expect( @ci.apply_summary ).to eq expected_summary
    end

    it "writes warning file when SIMP repo is not found by repoquery" do
      allow(@ci).to receive(:execute).with('repoquery -i kernel | grep ^Repository').and_return(true)
      allow(@ci).to receive(:execute).with('repoquery -i simp | grep ^Repository').and_return(false)
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
      expect( File.exist?(@warning_file) ).to eq true
    end

    it 'appends to warning file' do
      allow(@ci).to receive(:execute).with('repoquery -i kernel | grep ^Repository').and_return(true)
      allow(@ci).to receive(:execute).with('repoquery -i simp | grep ^Repository').and_return(false)
      FileUtils.mkdir_p(File.dirname(@warning_file))
      other_warning = "SOME OTHER WARNING"
      File.open(@warning_file, 'w') {|f| f.puts other_warning }
      @ci.apply
      actual_message = IO.read(@warning_file)
      expected_message = other_warning + "\n" + @ci.warning_message
      expect( actual_message).to eq other_warning + "\n" + @ci.warning_message
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'Checking of remote YUM configuration unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
