require 'simp/cli/config/items/action/set_hostname_action'

require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetHostnameAction do
  before :each do
    @ci = Simp::Cli::Config::Item::SetHostnameAction.new
  end

  # TODO:  test successes with acceptance tests
  describe "#apply" do
    it "will do set hostname " do
      cli_network_hostname = Simp::Cli::Config::Item::CliNetworkHostname.new
      cli_network_hostname.value = 'foo.bar.baz'

      expect(@ci).to receive(:get_item).with('cli::network::hostname').and_return(cli_network_hostname)
      expect(@ci).to receive(:execute).with("hostname #{cli_network_hostname.value}").and_return(true)
      expect(@ci).to receive(:execute).with("sed -i '/HOSTNAME/d' /etc/sysconfig/network").and_return(true)
      expect(@ci).to receive(:execute).with("echo HOSTNAME=#{cli_network_hostname.value} >> /etc/sysconfig/network").and_return(true)
      expect(File).to receive(:open).with('/etc/hostname', 'w')

      cli_network_dhcp = Simp::Cli::Config::Item::CliNetworkDHCP.new
      cli_network_dhcp.value = 'static'

      expect(@ci).to receive(:get_item).with('cli::network::dhcp').and_return(cli_network_dhcp)

      @ci.apply

      expect( @ci.applied_status ).to eq :succeeded
    end

    it 'sets applied_status to :failed when fails to set hostname' do
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
