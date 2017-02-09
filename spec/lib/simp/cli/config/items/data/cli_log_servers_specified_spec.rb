require 'simp/cli/config/items/data/cli_log_servers_specified'
require 'simp/cli/config/items/data/simp_options_syslog_log_servers'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliLogServersSpecified do
  before :each do
    @ci = Simp::Cli::Config::Item::CliLogServersSpecified.new
  end

  context '#recommended_value' do
    it "returns 'yes' when simp_options::syslog::log_servers is not empty" do
      item             = Simp::Cli::Config::Item::SimpOptionsSyslogLogServers.new
      item.value       =  ['1.2.3.4']
      @ci.config_items[item.key] = item

      expect( @ci.recommended_value ).to eq 'yes'
    end

    it "returns 'no' when simp_options::syslog::log_servers is empty" do
      item             = Simp::Cli::Config::Item::SimpOptionsSyslogLogServers.new
      item.value       =  []
      @ci.config_items[item.key] = item

      expect( @ci.recommended_value ).to eq 'no'
    end

    it 'fails when simp_options::syslog::log_servers item does not exist' do
      expect{ @ci.recommended_value }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::CliLogServersSpecified' +
        ' could not find simp_options::syslog::log_servers' )
    end
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
