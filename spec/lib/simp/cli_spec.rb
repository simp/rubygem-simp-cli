require 'spec_helper'
require 'simp/cli'


describe 'Simp::Cli' do

  before :all do
    @success_status = 0
    @failure_status = 1
    @result = nil
  end

  describe 'Simp::Cli.start' do
    describe 'help' do
      before :all do
        usage = <<EOM
SIMP Command Line Interface

Usage:

 simp -h
 simp COMMAND -h
 simp COMMAND [command options]

COMMANDS
  bootstrap     Bootstrap initial SIMP server
  config        Prepare SIMP server for bootstrapping
  doc           Show SIMP documentation in elinks
  environment   Utility to manage and coordinate SIMP omni-environments
  passgen       Utility for managing 'simplib::passgen' passwords
  puppetfile    Helper utility to maintain local SIMP Puppetfiles
  version       Display the current version of SIMP.

EOM
       @usage_regex = Regexp.new(Regexp.escape(usage))
      end

      it 'outputs general usage when no command specified' do
        expect{ @result = Simp::Cli.start([]) }.to output(@usage_regex).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs general usage when help command specified' do
        expect{ @result = Simp::Cli.start(['help']) }.to output(@usage_regex).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs general usage when -h specified' do
        expect{ @result = Simp::Cli.start(['-h']) }.to output(@usage_regex).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs general usage when --help specified' do
        expect{ @result = Simp::Cli.start(['--help']) }.to output(@usage_regex).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs general usage when invalid command specified' do
        expect{ @result = Simp::Cli.start(['oops']) }.to output(/oops is not a recognized command/).to_stderr
        expect( @result ).to be @failure_status
      end

      it 'outputs bootstrap usage when bootstrap help specified' do
        expect{ @result = Simp::Cli.start(['bootstrap', '-h']) }.to output(/=== The SIMP Bootstrap Tool ===/m).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs config usage when config help specified' do
        expect{ @result = Simp::Cli.start(['config', '-h']) }.to output(/=== The SIMP Configuration Tool ===/m).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs doc usage when doc help specified' do
        expect{ @result = Simp::Cli.start(['doc', '-h']) }.to output(/=== The SIMP Doc Tool ===/m).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs environment usage when environment help specified' do
        expect{ @result = Simp::Cli.start(['environment', '-h']) }.to output(/=== The SIMP Environment Tool ===/m).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs passgen usage when passgen help specified' do
        expect{ @result = Simp::Cli.start(['passgen', '-h']) }.to output(/=== The SIMP Passgen Tool ===/m).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs puppetfile usage when puppetfile help specified' do
        expect{ @result = Simp::Cli.start(['puppetfile', '-h']) }.to output(/=== The SIMP Puppetfile Tool ===/m).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs version usage when version help specified' do
        expect{ @result = Simp::Cli.start(['version', '-h']) }.to output(/Display the current version of SIMP/m).to_stdout
        expect( @result ).to be @success_status
      end
    end

    describe 'fails when invalid command option specified' do
      it 'fails to run bootstrap' do
        expect{ @result = Simp::Cli.start(['bootstrap', '--oops-bootstrap']) }.to output(
          /'bootstrap' command options error: invalid option: --oops-bootstrap/).to_stderr

        expect( @result ).to be @failure_status
      end

      it 'fails to run config' do
        expect{ @result = Simp::Cli.start(['config', '--oops-config']) }.to output(
          /'config' command options error: invalid option: --oops-config/).to_stderr

        expect( @result ).to be @failure_status
      end

      it 'fails to run passgen' do
        expect{ @result = Simp::Cli.start(['passgen', '--oops-passgen']) }.to output(
          /'passgen' command options error: invalid option: --oops-passgen/).to_stderr

        expect( @result ).to be @failure_status
      end

    end
  end
end

