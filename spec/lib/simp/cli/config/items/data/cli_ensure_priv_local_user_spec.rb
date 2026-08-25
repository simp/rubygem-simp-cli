# frozen_string_literal: true

require 'simp/cli/config/items/data/cli_ensure_priv_local_user'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliEnsurePrivLocalUser do
  before :each do
    @ci = described_class.new
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
