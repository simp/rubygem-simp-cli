require 'simp/cli/config/items/data/simp_options_ldap'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsLdap do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsLdap.new
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
