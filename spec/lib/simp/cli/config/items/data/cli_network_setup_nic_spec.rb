require 'simp/cli/config/items/data/cli_network_setup_nic'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliSetupNIC do
  before :each do
    @ci = Simp::Cli::Config::Item::CliSetupNIC.new
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
