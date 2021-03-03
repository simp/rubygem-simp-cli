require 'simp/cli/config/items/action_item'
require 'simp/cli/config/items/class_item'
require 'simp/cli/config/items/list_item'
require 'simp/cli/config/items/yes_no_item'

require 'spec_helper'
require 'rspec/its'

shared_examples 'a child of Simp::Cli::Config::Item' do
  describe '#to_yaml_s' do
    it 'does not contain FIXME' do
      expect( @ci.to_yaml_s ).not_to match(/FIXME/)
    end
  end

  describe '#key' do
    it 'returns a String' do
      expect( @ci.key ).to be_a_kind_of(String)
    end
  end
end


shared_examples "an Item that doesn't output YAML" do
  describe '#to_yaml_s' do
    it 'is empty' do
      expect( @ci.to_yaml_s.to_s ).to be_empty
    end
  end
end


shared_examples 'a yes/no validator' do
  describe "#validate" do
    it "validates yes/no" do
      expect( @ci.validate 'yes' ).to eq true
      expect( @ci.validate 'y' ).to   eq true
      expect( @ci.validate 'Y' ).to   eq true
      expect( @ci.validate 'no' ).to  eq true
      expect( @ci.validate 'n' ).to   eq true
      expect( @ci.validate 'NO' ).to  eq true
      expect( @ci.validate true ).to  eq true
      expect( @ci.validate false ).to eq true
    end

    it "doesn't validate other things" do
      expect( @ci.validate 'ydd' ).to  eq false
      expect( @ci.validate 'gsdg' ).to eq false
    end
  end

end

class TestItem < Simp::Cli::Config::Item
  attr_accessor :key, :description, :data_type
end

class TestListItem < Simp::Cli::Config::ListItem
  attr_accessor :key, :description, :data_type
end

class TestYesNoItem < Simp::Cli::Config::YesNoItem
  attr_accessor :key, :description, :data_type
end

class TestActionItem < Simp::Cli::Config::ActionItem
  attr_accessor :key, :description, :data_type
end

class TestClassItem < Simp::Cli::Config::ClassItem
  attr_accessor :key, :description, :data_type
end

