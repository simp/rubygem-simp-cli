require 'spec_helper'

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
  describe "#to_yaml_s" do
    it "is empty" do
      expect( @ci.to_yaml_s.to_s ).to be_empty
    end
  end
end
