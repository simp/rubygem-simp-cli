require 'simp/cli/config/items/data/cli_set_production_to_simp'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliSetProductionToSimp do
  before :each do
    @ci = Simp::Cli::Config::Item::CliSetProductionToSimp.new
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
