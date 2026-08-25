# frozen_string_literal: true

require 'simp/cli/config/items/data/simp_run_level'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpRunLevel do
  before :each do
    @ci = described_class.new
  end

  describe '#validate' do
    it 'validates simp_runlevel' do
      expect(@ci.validate('1')).to be true
      expect(@ci.validate('3')).to be true
      expect(@ci.validate('5')).to be true
    end

    it "doesn't validate bad simp_runlevel" do
      expect(@ci.validate('')).to be false
      expect(@ci.validate('0')).to be false
      expect(@ci.validate('7')).to be false
      expect(@ci.validate(nil)).to be false
      expect(@ci.validate(false)).to be false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
