require 'simp/cli/config/items/data/simp_options_tcpwrappers'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsTcpwrappers do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsTcpwrappers.new
    Facter.reset   # start with clean set of facts
  end

  describe '# os major version is available' do
    it "returns 'true' when OS version is 7" do
      allow(Facter).to receive(:value).with('os').and_return({ 'release' => { 'major' => '7', 'minor' => '5'}})
      expect( @ci.os_value ).to eq true
    end

    it "returns 'true' when OS version is 8" do
      allow(Facter).to receive(:value).with('os').and_return({ 'release' => { 'major' => '8', 'minor' => '1000'}})
      expect( @ci.os_value ).to eq false
    end
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
