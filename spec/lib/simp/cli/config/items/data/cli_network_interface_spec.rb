require 'simp/cli/config/items/data/cli_network_interface'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliNetworkInterface do
  let(:networking_fact) {
    {
      'interfaces' => {
        'br1'    => { 'ip' => '10.0.2.10' },
        'enp0s3' => {},
        'lo'     => { 'ip' => '127.0.0.1' },
      },
      'ip'        => '10.0.2.10',
      'primary'   => 'br1'
    }
  }

  before :each do
    @ci = Simp::Cli::Config::Item::CliNetworkInterface.new
  end

  describe '#initialize' do
    subject{ @ci }
    its(:key){ is_expected.to eq( 'cli::network::interface') }
  end

  describe '#get_recommended_value' do
    it "returns nil when 'networking' fact does not exist" do
      allow(Facter).to receive(:value).with('networking').and_return(nil)
      expect( @ci.get_recommended_value ).to be_nil
    end

    it 'returns primary interface when it exists and has an IPv4 addr' do
      allow(Facter).to receive(:value).with('networking').and_return(networking_fact)
      expect( @ci.get_recommended_value ).to eq 'br1'
    end

    it 'returns 1st br interface with IPv4 addr when primary with IPv4 does not exist' do
      net_fact = {
        'interfaces' => {
          'br1'    => {},
          'br2'    => { 'ip' => '10.0.2.10' },
          'enp0s3' => {},
          'enp0s4' => { 'ip' => '10.0.2.20' },
          'enp0s5' => {}
        },
      }
      allow(Facter).to receive(:value).with('networking').and_return(net_fact)
      expect( @ci.get_recommended_value ).to eq 'br2'
    end

    { 'en'   => 'enp0s',
      'em'   => 'em',
      'p#p#' => 'p1p',
      'eth'  => 'eth'
    }.each do |dev_prefix, example|
      it "returns 1st #{dev_prefix} with IPv4 addr when primary with IPv4 does not exist" do
        net_fact = {
          'interfaces' => {
            "#{example}1" => {},
            "#{example}2" => { 'ip' => '10.0.2.20' },
            "#{example}3" => { 'ip' => '10.0.2.30' }
          },
        }

        allow(Facter).to receive(:value).with('networking').and_return(net_fact)
        expect( @ci.get_recommended_value ).to eq "#{example}2"
      end
    end

    it 'returns 1st other interface with IPv4 addr when primary with IPv4 does not exist' do
      net_fact = {
        'interfaces' => {
          'enp0s2' => {},
          'vlan5' => { 'ip' => '10.0.2.20' },
          'vlan6' => { 'ip' => '10.0.2.30' }
        },
      }
      allow(Facter).to receive(:value).with('networking').and_return(net_fact)
      expect( @ci.get_recommended_value ).to eq 'vlan5'
    end

    { 'en'   => 'enp0s',
      'em'   => 'em',
      'p#p#' => 'p1p',
      'eth'  => 'eth'
    }.each do |dev_prefix, example|
      it "returns 1st #{dev_prefix} without an IPv4 address when none have IPv4" do
        net_fact = {
          'interfaces' => {
            "#{example}1" => {},
            "#{example}2" => {},
            "#{example}3" => {},
          },
        }

        allow(Facter).to receive(:value).with('networking').and_return(net_fact)
        expect( @ci.get_recommended_value ).to eq "#{example}1"
      end
    end

  end

  describe '#interfaces' do
    it 'extracts non-loopback interfaces from the networking fact' do
      allow(Facter).to receive(:value).with('networking').and_return(networking_fact)
      expect( @ci.interfaces ).to eq( { 'br1' => '10.0.2.10', 'enp0s3' => nil } )
    end

    it 'returns empty fact when networking fact does not exist' do
      allow(Facter).to receive(:value).with('networking').and_return(nil)
      expect( @ci.interfaces ).to eq( {} )
    end
  end

  describe '#interface_table' do
    it 'returns table with non-loopback interfaces from the networking fact' do
      allow(Facter).to receive(:value).with('networking').and_return(networking_fact)
      expected = <<~EOM
        AVAILABLE INTERFACES:
            Interface  IP Address
            ---------  ----------
            br1        10.0.2.10
            enp0s3     N/A
      EOM
      expect( @ci.interface_table ).to eq expected.strip
    end

    it 'returns empty table when networking fact does not exist' do
      allow(Facter).to receive(:value).with('networking').and_return(nil)
      expect( @ci.interface_table ).to eq ''
    end
  end

  describe '#not_valid_message' do
    it 'lists available interfaces' do
      allow(Facter).to receive(:value).with('networking').and_return(networking_fact)
      expected = <<~EOM
        Acceptable values:
          br1
          enp0s3
      EOM
      expect( @ci.not_valid_message ).to eq expected.strip
    end
  end

  describe '#validate' do
    it "doesn't validate nonsensical interfaces" do
      allow(Facter).to receive(:value).with('networking').and_return(networking_fact)
      expect( @ci.validate( 'lo' ) ).to eq false
      expect( @ci.validate( '' ) ).to eq false
      expect( @ci.validate( 'nerbaderp' ) ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
