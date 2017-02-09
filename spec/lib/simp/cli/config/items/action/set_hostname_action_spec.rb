require 'simp/cli/config/items/action/set_hostname_action'
require 'simp/cli/config/items/data/cli_network_hostname'

require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetHostnameAction do
  before :each do
    @ci = Simp::Cli::Config::Item::SetHostnameAction.new
  end

  # TODO:  test successes with acceptance tests
  describe "#apply" do
    it "will do set hostname " do
      skip "FIXME: how shall we test SetHostnameAction#apply()?"
    end

    it 'sets applied_status to :failed when fails to set hostname' do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
      cli_network_hostname = Simp::Cli::Config::Item::CliNetworkHostname.new
      cli_network_hostname.value = 'oops.test.local'
      @ci.config_items = { cli_network_hostname.key => cli_network_hostname }
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'Setting of hostname unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
end
