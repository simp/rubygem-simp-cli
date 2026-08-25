# frozen_string_literal: true

require 'simp/cli/config/items/data/cli_network_dhcp'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliNetworkDHCP do
  before :each do
    @ci = described_class.new
  end

  describe '#validate' do
    it 'validates dhcp/static' do
      expect(@ci.validate('dhcp')).to be true
      expect(@ci.validate('static')).to be true
    end

    it "doesn't validate other things" do
      expect(@ci.validate('oops')).to be false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
