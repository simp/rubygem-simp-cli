# frozen_string_literal: true

require 'simp/cli/config/items/data/cli_puppet_server_ip'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliPuppetServerIP do
  before :each do
    @ci = described_class.new
  end

  describe '#validate' do
    it 'validates IPv4 IPs' do
      expect(@ci.validate('192.168.1.1')).to be true
    end

    it "doesn't validate bad IPs" do
      expect(@ci.validate('x.x.x.x')).to be false
      expect(@ci.validate('999.999.999.999')).to be false
      expect(@ci.validate('192.168.1.1/24')).to be false
      expect(@ci.validate(nil)).to be false
      expect(@ci.validate(false)).to be false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
