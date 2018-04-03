require 'simp/cli/config/items/data/simp_options_ntp_servers'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsNTPServers do
  before :all do
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )
  end

  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsNTPServers.new
    @ci.silent = true
  end

#  describe '#recommended_value' do
#  TODO: how to test this when os_value returns a valid value?
#    it 'recommends nil when network::gateway is unavailable' do
#      expect( @ci.recommended_value ).to be_nil
#    end
#  end

  describe '#validate' do
    it 'validates array with good hosts' do
      expect( @ci.validate ['pool.ntp.org'] ).to eq true
      expect( @ci.validate ['192.168.1.1'] ).to eq true
      expect( @ci.validate ['192.168.1.1', 'pool.ntp.org'] ).to eq true
      # NTP servers are optional, so nil is okay
      expect( @ci.validate nil   ).to eq true
    end

    it "doesn't validate array with bad hosts" do
      expect( @ci.validate 0     ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate [nil] ).to eq false
      expect( @ci.validate ['pool.ntp.org-'] ).to eq false
      expect( @ci.validate ['192.168.1.1.'] ).to eq false
      expect( @ci.validate ['1.2.3.4/24'] ).to eq false
    end

    it 'accepts an empty list' do
      expect( @ci.validate [] ).to eq true
      expect( @ci.validate '' ).to eq true
    end
  end

  describe '#get_os_value' do
    it 'returns empty array when ntp.conf is not accessible' do
      expect( @ci.get_os_value('/does/not/exist') ).to eq []
    end

    it 'returns empty array when ntp.conf has no servers' do
      expect( @ci.get_os_value(File.join(@files_dir,'ntp.conf_no_servers')) ).to eq []
    end

    it 'returns empty array when ntp.conf has only local servers' do
      expect( @ci.get_os_value(File.join(@files_dir,'ntp.conf_local_servers')) ).to eq []
    end

    it 'returns array of only remote servers when ntp.conf lists remote and local servers' do
      expected = [
        '0.north-america.pool.ntp.org',
        '1.north-america.pool.ntp.org',
        '2.north-america.pool.ntp.org',
        '3.north-america.pool.ntp.org'
      ]
      expect( @ci.get_os_value(File.join(@files_dir,'ntp.conf_remote_servers')) ).to eq expected
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
