require 'simp/cli/config/items/action/configure_network_action'

require 'simp/cli/config/items/data/cli_network_dhcp'
require 'simp/cli/config/items/data/cli_network_gateway'
require 'simp/cli/config/items/data/cli_network_hostname'
require 'simp/cli/config/items/data/cli_network_interface'
require 'simp/cli/config/items/data/cli_network_ipaddress'
require 'simp/cli/config/items/data/cli_network_netmask'
require 'simp/cli/config/items/data/simp_options_dns_search'
require 'simp/cli/config/items/data/simp_options_dns_servers'

require_relative '../spec_helper'

describe Simp::Cli::Config::Item::ConfigureNetworkAction do
  before :each do
    @ci = Simp::Cli::Config::Item::ConfigureNetworkAction.new
  end


  # TODO: test successes with acceptance tests
  describe "#apply" do
    it "will puppet apply a static network interface" do
      @ci.config_items = init_config_items( {'network::dhcp' => 'static'} )
      skip "FIXME: how shall we test ConfigureNetworkAction#apply()?"
      @ci.apply
    end

    it "will puppet apply a dhcp network interface" do
      @ci.config_items = init_config_items( {'network::dhcp' => 'dhcp'} )
      skip "FIXME: how shall we test ConfigureNetworkAction#apply()?"
      @ci.apply
    end

    it 'sets applied_status to :failed when puppet apply fails to configure network' do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
      @ci.config_items = init_config_items( {'network::dhcp' => 'static'} )
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
    end

  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'Configuration of a network interface unattempted'
    end
  end

  # helper method to create a number of previous answers
  def init_config_items( extra_answers={} )
    answers = {}
    things  = {
      'CliNetworkInterface'      => 'oops',
      'CliNetworkDHCP'           => 'static',
      'CliNetworkHostname'       => 'myhost.mytest.local',
      'CliNetworkIPAddress'      => '10.0.71.50',
      'CliNetworkNetmask'        => '255.255.255.0',
      'CliNetworkGateway'        => '10.0.71.1',
      'SimpOptionsDNSServers' => ['10.0.71.7', '8.8.8.8'],
      'SimpOptionsDNSSearch'  => 'mytest.local',
    }
    things.each do |name,value|
      item = Simp::Cli::Config::Item.const_get(name).new
      if extra_answers.keys.include? item.key
        item.value = extra_answers.fetch( item.key )
      else
        item.value = value
      end
      answers[ item.key ] = item
    end
    answers
  end

  it_behaves_like "an Item that doesn't output YAML"
  #it_behaves_like "a child of Simp::Cli::Config::Item"
end
