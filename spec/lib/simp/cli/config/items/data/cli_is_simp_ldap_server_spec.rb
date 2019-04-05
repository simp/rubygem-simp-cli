require 'simp/cli/config/items/data/cli_is_simp_ldap_server'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliIsSimpLdapServer do
  before :each do
    @ci = Simp::Cli::Config::Item::CliIsSimpLdapServer.new
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
