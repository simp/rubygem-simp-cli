require 'simp/cli/config/items/data/simp_options_dns_servers'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsDNSServers do
  before :all do
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )
  end

  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsDNSServers.new
    # logger is a singleton that may or may not be hanging
    # around from previous tests. To make sure file
    # output doesn't get dumped to the screen, set that level
    # super high.
    @ci.logger.levels(:info, :fatal)
  end

  describe '#get_os_value' do
    it 'returns [] when nmcli is not found' do
      allow(Facter::Core::Execution).to receive(:which).with('nmcli').and_return(nil)

      expect(@ci.get_os_value).to eq []
    end

    # remaining cases are tested via recommended_value tests
  end

  describe '#recommended_value' do
    before :each do
      allow(Facter::Core::Execution).to receive(:which).with('nmcli').and_return('/usr/bin/nmcli')
    end

    let(:nmcli_cmd) { '/usr/bin/nmcli -g IP4.DNS dev show' }

    context 'when nmcli returns DNS servers' do
      it 'handles a single nameserver' do
        expect(@ci).to receive(:run_command).with(nmcli_cmd, true)
          .and_return({ :stdout => "10.0.0.1\n\n" })

        expect(@ci.recommended_value.size).to eq 1
        expect(@ci.recommended_value).to eq ['10.0.0.1']
      end

      it 'handles multiple nameservers' do
        expect(@ci).to receive(:run_command).with(nmcli_cmd, true)
          .and_return({ :stdout => "10.0.0.1\n10.0.0.2\n10.0.0.3\n\n" })

        expect(@ci.recommended_value.size).to eq 3
        expect(@ci.recommended_value).to eq ['10.0.0.1', '10.0.0.2', '10.0.0.3']
      end

      it 'handles extraneous blank lines in output' do
        expect(@ci).to receive(:run_command).with(nmcli_cmd, true)
          .and_return({ :stdout => "10.0.0.1\n\n10.0.0.2\n\n10.0.0.3\n\n\n" })

        expect(@ci.recommended_value.size).to eq 3
        expect(@ci.recommended_value).to eq ['10.0.0.1', '10.0.0.2', '10.0.0.3']
      end
    end

    context 'when nmcli does not return any DNS servers' do
      it 'recommends ipaddress (when available)' do
        ip = Simp::Cli::Config::Item::CliNetworkIPAddress.new
        ip.value = '1.2.3.4'
        @ci.config_items[ ip.key ] = ip

        expect(@ci).to receive(:run_command).with(nmcli_cmd, true)
          .and_return({ :stdout =>"\n\n" })

        expect(@ci.recommended_value).to eq ['1.2.3.4']
      end

      it 'recommends a must-change value (when ipaddress is not available)' do
        expect(@ci).to receive(:run_command).with(nmcli_cmd, true)
          .and_return({ :stdout => "\n\n" })

        expect(@ci.recommended_value.first).to match( /CHANGE THIS/ )
      end
    end
  end

  describe '#validate' do
    it 'validates array with good IPs' do
      expect( @ci.validate ['10.0.71.1']              ).to eq true
      expect( @ci.validate ['192.168.1.1', '8.8.8.8'] ).to eq true
    end

    it "doesn't validate array with bad IPs" do
      expect( @ci.validate [nil]          ).to eq false
      expect( @ci.validate ['1.2.3']      ).to eq false
      expect( @ci.validate ['1.2.3.999']  ).to eq false
      expect( @ci.validate ['8.8.8.8.']   ).to eq false
      expect( @ci.validate ['1.2.3.4.5']  ).to eq false
      expect( @ci.validate ['1.2.3.4/24'] ).to eq false
    end

    it "doesn't validate empty array" do
      expect( @ci.validate []         ).to eq false
    end

    it "doesn't validate nonsense" do
      expect( @ci.validate 0             ).to eq false
      expect( @ci.validate nil           ).to eq false
      expect( @ci.validate false         ).to eq false
    end
  end

  describe '#determine_value' do
    context "accepts recommended values and displays options and selection" do
      before do
        @input = StringIO.new("\n")
        @output = StringIO.new
        HighLine.default_instance = HighLine.new(@input, @output)
      end

      after do
        @input.close
        @output.close
        HighLine.default_instance = HighLine.new
      end

      it 'handles a single nameserver' do
        expect(@ci).to receive(:get_os_value).and_return ['10.0.0.1']
        @ci.determine_value(true, false) # query, don't force
        expect( @ci.value ).to eq ['10.0.0.1']
        list = '\["10.0.0.1"\]'
        r = /OS value:\s+#{list}.* Recommended value:\s+#{list}.* simp_options::dns::servers = .*#{list}/m
        expect( @output.string ).to match r
      end

      it 'handles multiple nameservers' do
        expect(@ci).to receive(:get_os_value).and_return ['10.0.0.1', '10.0.0.2', '10.0.0.3']
        @ci.determine_value(true, false) # query, don't force
        expect( @ci.value ).to eq ['10.0.0.1', '10.0.0.2', '10.0.0.3']
        list = '\["10.0.0.1", "10.0.0.2", "10.0.0.3"\]'
        r = /OS value:\s+#{list}.* Recommended value:\s+#{list}.* simp_options::dns::servers = .*#{list}/m
        expect( @output.string ).to match r
      end

    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end

