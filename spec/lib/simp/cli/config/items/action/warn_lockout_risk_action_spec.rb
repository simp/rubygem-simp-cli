require 'simp/cli/config/items/action/warn_lockout_risk_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::WarnLockoutRiskAction do
  before :each do
    @ci        = Simp::Cli::Config::Item::WarnLockoutRiskAction.new
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

    it "writes warning file" do
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
      expect( File.exist?(@warning_file) ).to eq true
      actual_message = IO.read(@warning_file)
      expect( actual_message).to eq @ci.warning_message
      expected_summary =
        %r{^'simp bootstrap' has been locked due to potential login lockout\.\n  \* See /.+/simp_bootstrap_start_lock for details$}
      expect( @ci.apply_summary ).to match expected_summary
    end

    it "appends warning file" do
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
      expect(@ci.apply_summary).to eq 'Check for login lockout risk unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
