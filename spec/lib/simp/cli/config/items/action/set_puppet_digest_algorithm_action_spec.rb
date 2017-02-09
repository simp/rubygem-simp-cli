require 'simp/cli/config/items/action/set_puppet_digest_algorithm_action'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetPuppetDigestAlgorithmAction do
  before :each do
    @ci = Simp::Cli::Config::Item::SetPuppetDigestAlgorithmAction.new
  end

  describe "#apply" do
    it 'sets puppet digest algorithm'do
     @ci.apply
     expect( @ci.applied_status ).to eq :succeeded
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq(
        'Setting of Puppet digest algorithm to sha256 for FIPS unattempted')
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
