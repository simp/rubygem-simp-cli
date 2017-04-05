require 'simp/cli/config/items/data/cli_use_internet_simp_yum_repos'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliUseInternetSimpYumRepos do
  before :each do
    @ci = Simp::Cli::Config::Item::CliUseInternetSimpYumRepos.new
  end

  context "#recommended_value" do
    it "returns 'yes'" do
      expect( @ci.recommended_value).to eq 'yes'
    end
 
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
