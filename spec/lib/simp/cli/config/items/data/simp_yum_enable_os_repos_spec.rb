require 'simp/cli/config/items/data/simp_yum_enable_os_repos'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpYumEnableOsRepos do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpYumEnableOsRepos.new
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
