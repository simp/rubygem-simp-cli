require 'simp/cli/config/items/item'
require 'rspec/its'
require 'spec_helper'

describe Simp::Cli::Config::Item do
  before :each do
    @ci = Simp::Cli::Config::Item.new
  end

  describe '#initialize' do
    it 'has no value when initialized' do
      expect( @ci.value ).to eq nil
    end

    it 'has nil os_value when initialized' do
      expect( @ci.os_value ).to be_nil
    end

    it 'has nil recommended_value when initialized' do
      expect( @ci.recommended_value ).to be_nil
    end

  end

  describe '#to_yaml_s' do
    it 'raises a Simp::Cli::Config::InternalError if @key is empty' do
      @ci.key = nil
      expect{ @ci.to_yaml_s }.to raise_error( Simp::Cli::Config::InternalError )
    end

    it 'uses FIXME message as description if description is not set' do
      @ci.key = 'mykey'
      expect( @ci.to_yaml_s ).to match(/FIXME/)
    end

    it 'returns nil instead of YAML key/value if @skip_yaml=true' do
      @ci.key = 'mykey'
      @ci.value = 'myvalue'
      @ci.skip_yaml = true
      expect( @ci.to_yaml_s ).to eq(nil)
    end
  end

  describe '#print_summary' do
    it 'raises Simp::Cli::Config::InternalError on nil @key' do
      @ci.key = nil
      expect{ @ci.print_summary }.to raise_error( Simp::Cli::Config::InternalError )
    end

    it 'raises a Simp::Cli::Config::InternalError on empty @key' do
      @ci.key = ''
      expect{ @ci.print_summary }.to raise_error( Simp::Cli::Config::InternalError )
    end
  end

  describe '#run_command' do
    it 'should reject pipes' do
      command = 'ls /some/missing/path1 | grep path1'
      expect{ @ci.run_command(command) }.to raise_error("Internal error: Invalid pipe '|' in spawn command: <ls /some/missing/path1 | grep path1>")
    end

    it 'returns true when command succeeeds' do
      command = "ls #{__FILE__}"
      expect( @ci.run_command(command)[:status] ).to eq true
      expect( @ci.run_command(command)[:stdout] ).to match "#{__FILE__}"
      expect( @ci.run_command(command)[:stderr] ).to eq ''
    end

    it 'returns false when command fails and ignore_failure is false' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @ci.run_command(command)[:status] ).to eq false
      expect( @ci.run_command(command)[:stdout] ).to eq ''
      expect( @ci.run_command(command)[:stderr] ).to match /ls: cannot access.*\/some\/missing\/path1.*: No such file or directory/
    end

    it 'returns true when command fails and ignore_failure is true' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @ci.run_command(command, true)[:status] ).to eq true
      expect( @ci.run_command(command)[:stdout] ).to eq ''
      expect( @ci.run_command(command)[:stderr] ).to match /ls: cannot access.*\/some\/missing\/path1.*: No such file or directory/
    end
  end

  describe '#execute' do
    it 'should reject pipes' do
      command = "ls /some/missing/path1 | grep path1"
      expect{ @ci.run_command(command) }.to raise_error("Internal error: Invalid pipe '|' in spawn command: <ls /some/missing/path1 | grep path1>")
    end

    it 'returns true when command succeeeds' do
      command = "ls #{__FILE__}"
      expect( @ci.execute(command) ).to eq true
    end

    it 'returns false when command fails and ignore_failure is false' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @ci.execute(command) ).to eq false
    end

    it 'returns true when command fails and ignore_failure is true' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @ci.execute(command, true) ).to eq true
    end
  end

  describe '#get_os_value' do
    it 'has nil value when @fact is nil' do
      expect( @ci.get_os_value ).to be_nil
    end

    it 'does not have nil value when @fact is set' do
      @ci.fact = 'interfaces'
      expect( @ci.get_os_value ).to_not be_nil
    end
  end
end
