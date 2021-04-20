require 'simp/cli/config/items/action/warn_client_yum_config_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::WarnClientYumConfigAction do
  before :each do
    @ci        = Simp::Cli::Config::Item::WarnClientYumConfigAction.new
    @ci.silent = true # uncomment out this line to see log message
  end

  describe "#apply" do
    it "sets applied_status to deferred" do
      @ci.apply
      expect( @ci.applied_status ).to eq :deferred
      expected_summary =<<EOM
Checking YUM configuration for SIMP clients deferred:
    Your SIMP client YUM configuration requires manual verification
EOM
      expect( @ci.apply_summary ).to eq expected_summary.strip
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq(
        'Checking YUM configuration for SIMP clients unattempted')
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
