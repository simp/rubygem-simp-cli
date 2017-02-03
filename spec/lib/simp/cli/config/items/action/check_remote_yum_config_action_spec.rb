require 'simp/cli/config/items/action/check_remote_yum_config_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CheckRemoteYumConfigAction do
  before :each do
    @ci        = Simp::Cli::Config::Item::CheckRemoteYumConfigAction.new
    @ci.silent = true # uncomment out this line to see log message
  end

  describe "#apply" do
    it "writes warning file" do
      tmp_dir         = Dir.mktmpdir( File.basename(__FILE__) )
      warning_file    = File.join(tmp_dir, '.simp', 'simp_bootstrap_start_lock')
      @ci.warning_file = warning_file
      @ci.apply
      expect( @ci.applied_status ).to eq :deferred
      expect( File.exist?(warning_file) ).to eq true
      actual_message = IO.read(warning_file)
      expect( actual_message).to eq @ci.warning_message
      expected_summary = 
        "Your YUM configuration may be incomplete.  Verify you have set up system (OS)\n" +
        "    updates and SIMP repositories before running 'simp bootstrap'."
      expect( @ci.apply_summary ).to eq expected_summary
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'Checking remote YUM configuration unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
