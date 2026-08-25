# frozen_string_literal: true

require 'simp/cli/config/items/data/simp_options_syslog_failover_log_servers'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsSyslogFailoverLogServers do
  before :each do
    @ci = described_class.new
  end

  describe '#recommended_value' do
    it 'recommends nil' do
      expect(@ci.recommended_value).to be_nil
    end
  end

  describe '#validate' do
    it 'validates array with good hosts' do
      expect(@ci.validate(['log'])).to be true
      expect(@ci.validate(['log-server'])).to be true
      expect(@ci.validate(['log.loggitylog.org'])).to be true
      expect(@ci.validate(['192.168.1.1'])).to be true
      expect(@ci.validate(['192.168.1.1', 'log.loggitylog.org'])).to be true

      # failover_log_servers is optional and can be empty
      expect(@ci.validate(nil)).to be true
      expect(@ci.validate('')).to    be true
      expect(@ci.validate('   ')).to be true
    end

    it "doesn't validate array with bad hosts" do
      expect(@ci.validate(0)).to be false
      expect(@ci.validate(false)).to be false
      expect(@ci.validate([nil])).to be false
      expect(@ci.validate(['log-'])).to be false
      expect(@ci.validate(['-log'])).to be false
      expect(@ci.validate(['log.loggitylog.org-'])).to be false
      expect(@ci.validate(['.log.loggitylog.org'])).to be false
    end

    it 'accepts an empty list' do
      expect(@ci.validate([])).to be true
      expect(@ci.validate('')).to be true
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
