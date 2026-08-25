# frozen_string_literal: true

require 'simp/cli/config/items/data/simp_options_puppet_ca'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsPuppetCA do
  before :each do
    @ci = described_class.new
  end

  describe '#validate' do
    it 'validates fqdns' do
      expect(@ci.validate('puppet')).to be true
      expect(@ci.validate('puppet.change.me')).to be true
    end

    it "doesn't validate bad fqdns" do
      expect(@ci.validate('puppet-')).to be false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
