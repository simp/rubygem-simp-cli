require 'simp/cli/config/items/data/cli_set_grub_password'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliSetGrubPassword do
  before :each do
    @ci = Simp::Cli::Config::Item::CliSetGrubPassword.new
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
