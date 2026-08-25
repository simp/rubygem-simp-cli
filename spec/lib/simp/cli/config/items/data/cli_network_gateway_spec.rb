# frozen_string_literal: true

require 'simp/cli/config/items/data/cli_network_gateway'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliNetworkGateway do
  before :each do
    @ci = described_class.new
  end

  describe '#validate' do
    it 'validates plausible gateways' do
      expect(@ci.validate('192.168.1.0')).to be true
    end

    it "doesn't validate impossible gateways" do
      expect(@ci.validate(nil)).to be false
      expect(@ci.validate(false)).to be false
      expect(@ci.validate('999.999.999.999')).to be false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
