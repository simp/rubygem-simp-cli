require 'simp/cli/config/items/action/configure_network_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::ConfigureNetworkAction do
  before :each do
    stub_const('Simp::Cli::SIMP_MODULES_INSTALL_PATH', '')
    @puppet_env_info = {
      :puppet_config => { 'modulepath' => '/some/module/path' }
    }
    @ci = Simp::Cli::Config::Item::ConfigureNetworkAction.new(@puppet_env_info)
    @cmd_prefix =  [
      'FACTER_ipaddress=XXX',
      'puppet apply',
      '--modulepath=/some/module/path',
      '--digest_algorithm=sha256',
    ].join(' ')
  end

  # TODO: test successes with acceptance tests
  describe "#apply" do
    before(:each) do
      @cli_network_interface = Simp::Cli::Config::Item::CliNetworkInterface.new(@puppet_env_info)
      @cli_network_interface.value = 'ethFake'
      expect(@ci).to receive(:get_item).with('cli::network::interface').and_return(@cli_network_interface)
    end

    context 'static' do
      before(:each) do
        @cli_network_dhcp = Simp::Cli::Config::Item::CliNetworkDHCP.new(@puppet_env_info)
        @cli_network_dhcp.value = 'static'

        @ci.config_items = init_config_items( {'network::dhcp' => @cli_network_dhcp.value} )

        @cli_network_ipaddress = Simp::Cli::Config::Item::CliNetworkIPAddress.new(@puppet_env_info)
        @cli_network_ipaddress.value = '1.2.3.4'

        @cli_network_hostname = Simp::Cli::Config::Item::CliNetworkHostname.new(@puppet_env_info)
        @cli_network_hostname.value = 'foo.bar.baz'

        @cli_network_netmask = Simp::Cli::Config::Item::CliNetworkNetmask.new(@puppet_env_info)
        @cli_network_netmask.value = '255.255.255.0'

        @cli_network_gateway = Simp::Cli::Config::Item::CliNetworkGateway.new(@puppet_env_info)
        @cli_network_gateway.value = '1.0.0.1'

        @simp_options_dns_search = Simp::Cli::Config::Item::SimpOptionsDNSSearch.new(@puppet_env_info)
        @simp_options_dns_search.value = ['dns.bar.baz']

        @simp_options_dns_servers = Simp::Cli::Config::Item::SimpOptionsDNSServers.new(@puppet_env_info)
        @simp_options_dns_servers.value = ['1.1.1.1', '1.1.1.2']

        expect(@ci).to receive(:get_item).with('cli::network::dhcp').and_return(@cli_network_dhcp)
        expect(@ci).to receive(:get_item).with('cli::network::ipaddress').and_return(@cli_network_ipaddress)
        expect(@ci).to receive(:get_item).with('cli::network::hostname').and_return(@cli_network_hostname)
        expect(@ci).to receive(:get_item).with('cli::network::netmask').and_return(@cli_network_netmask)
        expect(@ci).to receive(:get_item).with('cli::network::gateway').and_return(@cli_network_gateway)
        expect(@ci).to receive(:get_item).with('simp_options::dns::search').and_return(@simp_options_dns_search)
        expect(@ci).to receive(:get_item).with('simp_options::dns::servers').and_return(@simp_options_dns_servers)

        @ci.config_items = init_config_items( {'network::dhcp' => 'static'} )
      end

      it 'sets applied_status to :failed when puppet apply fails to configure network' do
        cmd = [
          @cmd_prefix,
          "-e \"network::eth{'#{@cli_network_interface.value}': bootproto => 'none', onboot => true, ipaddr => '#{@cli_network_ipaddress.value}', netmask => '#{@cli_network_netmask.value}', gateway => '#{@cli_network_gateway.value}' } class{ 'resolv': resolv_domain => '#{@cli_network_hostname.value.split('.')[1..-1].join('.')}', servers => ['#{@simp_options_dns_servers.value.join("','")}'], search => ['#{@simp_options_dns_search.value.join("','")}'], named_autoconf => false, }\""
        ].join(' ')
        expect(@ci).to receive(:execute).with(cmd).and_return(false)

        @ci.apply

        expect( @ci.applied_status ).to eq :failed
      end

      it "will puppet apply a network interface" do
        cmd = [
          @cmd_prefix,
          "-e \"network::eth{'#{@cli_network_interface.value}': bootproto => 'none', onboot => true, ipaddr => '#{@cli_network_ipaddress.value}', netmask => '#{@cli_network_netmask.value}', gateway => '#{@cli_network_gateway.value}' } class{ 'resolv': resolv_domain => '#{@cli_network_hostname.value.split('.')[1..-1].join('.')}', servers => ['#{@simp_options_dns_servers.value.join("','")}'], search => ['#{@simp_options_dns_search.value.join("','")}'], named_autoconf => false, }\""
        ].join(' ')
        expect(@ci).to receive(:execute).with(cmd).and_return(true)

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
      end
    end

    context 'dhcp' do
      it "will puppet apply a dhcp network interface" do
        cli_network_dhcp = Simp::Cli::Config::Item::CliNetworkDHCP.new(@puppet_env_info)
        cli_network_dhcp.value = 'dhcp'

        @ci.config_items = init_config_items( {'network::dhcp' => cli_network_dhcp.value} )

        expect(@ci).to receive(:get_item).with('cli::network::dhcp').and_return(cli_network_dhcp)

        cmd = [
          @cmd_prefix,
          "-e \"network::eth{'#{@cli_network_interface.value}': bootproto => '#{cli_network_dhcp.value}', onboot => true}\""
        ].join(' ')
        expect(@ci).to receive(:execute).with(cmd).and_return(true)

        expect(Facter).to receive(:clear)
        expect(Facter).to receive(:value).with("ipaddress_#{@cli_network_interface.value}").and_return('1.2.3.4')

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
      end
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
      item = Simp::Cli::Config::Item.const_get(name).new(@puppet_env_info)
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
