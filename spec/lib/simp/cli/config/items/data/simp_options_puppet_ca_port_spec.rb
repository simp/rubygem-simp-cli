require 'simp/cli/config/items/data/simp_options_puppet_ca_port'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsPuppetCAPort do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsPuppetCAPort.new
  end

  describe '#validate' do
    it 'validates acceptable ca ports' do
      expect( @ci.validate '8140' ).to eq true
      expect( @ci.validate '8141' ).to eq true
    end

    it "doesn't validate bad ca ports" do
      expect( @ci.validate 'puppet' ).to eq false
      expect( @ci.validate '70000' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
