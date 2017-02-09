require 'simp/cli/config/items/data/cli_is_ldap_server'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliIsLdapServer do
  before :each do
    @ci = Simp::Cli::Config::Item::CliIsLdapServer.new
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
