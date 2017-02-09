require 'simp/cli/config/items/list_item'
require 'rspec/its'
require 'spec_helper'

describe Simp::Cli::Config::ListItem do
  before :each do
    @ci = Simp::Cli::Config::ListItem.new
  end

  context "when @allow_empty_list = true" do
    before :each do
      @ci.allow_empty_list = false
      @ci.value = []
    end

    describe "#validate" do
      it "doesn't validate an empty array" do
        expect( @ci.validate [] ).to eq false
      end
    end
  end
end
