require 'simp/cli/config/items/action_item'
require 'rspec/its'
require 'spec_helper'

describe Simp::Cli::Config::ActionItem do
  before :each do
    @ci         = Simp::Cli::Config::ActionItem.new
    @ci.key     = "action::item"
  end

  describe "#initialize" do
    it "has 'unattempted' applied_status when initialized" do
      expect( @ci.applied_status ).to eq :unattempted
    end
  end

  # #safe_apply is tested via derived classes
end
