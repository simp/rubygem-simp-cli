require 'simp/cli/config/items/data/simp_options_fips'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsFips do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsFips.new
    Facter.reset   # start with clean set of facts
  end

  describe '#os_value when fips_enabled fact is available' do
    it "returns 'true' when fips_enabled fact returns true" do
      allow(Facter).to receive(:value).with('fips_enabled').and_return(true)
      expect( @ci.os_value ).to eq 'yes'
    end

    it "returns 'no' when fips_enabled fact returns false" do
      allow(Facter).to receive(:value).with('fips_enabled').and_return(false)
      expect( @ci.os_value ).to eq 'no'
    end
  end

  describe '#os_value when fips_enabled fact is not available' do
    # without simplib installed, custom fips_enabled fact is not present
    it "returns 'no'" do
      allow(Facter).to receive(:value).with('fips_enabled').and_return(nil)
      expect( @ci.os_value ).to eq 'no'
    end
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
