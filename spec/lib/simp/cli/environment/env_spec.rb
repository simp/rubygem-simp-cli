# frozen_string_literal: true

require 'simp/cli/environment/env'
require 'spec_helper'

describe Simp::Cli::Environment::Env do
  describe '#new' do
    # rubocop:disable RSpec/MultipleExpectations
    it 'requires an acceptable environment name' do
      expect { described_class.new(:puppet, 'acceptable_name', {}) }.not_to raise_error
      expect { described_class.new(:puppet, '-2354', {}) }.to raise_error(ArgumentError, %r{Illegal environment name})
      expect { described_class.new(:puppet, '2abc_def', {}) }.to raise_error(ArgumentError, %r{Illegal environment name})
    end
    # rubocop:enable RSpec/MultipleExpectations
  end

  describe '#type' do
    # rubocop:disable RSpec/MultipleExpectations
    it 'should return type' do
      expect( described_class.new(:puppet, 'testenv', {}).type ).to eq :puppet
      expect( described_class.new('puppet', 'testenv', {}).type ).to eq 'puppet'
    end
    # rubocop:enable RSpec/MultipleExpectations
  end

  describe '#run_command' do
    before :each do
      @env = described_class.new(:puppet, 'testenv', {})
    end

    # rubocop:disable RSpec/MultipleExpectations
    it 'should reject pipes' do
      command = 'ls /some/missing/path1 | grep path1'
      expect{ @env.run_command(command) }.to raise_error("Internal error: Invalid pipe '|' in spawn command: <ls /some/missing/path1 | grep path1>")
    end

    it 'returns true when command succeeeds' do
      command = "ls #{__FILE__}"
      expect( @env.run_command(command)[:status] ).to eq true
      expect( @env.run_command(command)[:stdout] ).to match "#{__FILE__}"
      expect( @env.run_command(command)[:stderr] ).to eq ''
    end

    it 'returns false when command fails and ignore_failure is false' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @env.run_command(command)[:status] ).to eq false
      expect( @env.run_command(command)[:stdout] ).to eq ''
      expect( @env.run_command(command)[:stderr] ).to match /ls: cannot access.*\/some\/missing\/path1.*: No such file or directory/
    end

    it 'returns true when command fails and ignore_failure is true' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @env.run_command(command, true)[:status] ).to eq true
      expect( @env.run_command(command)[:stdout] ).to eq ''
      expect( @env.run_command(command)[:stderr] ).to match /ls: cannot access.*\/some\/missing\/path1.*: No such file or directory/
    end
    # rubocop:enable RSpec/MultipleExpectations
  end

  describe '#execute' do
    before :each do
      @env = described_class.new(:puppet, 'testenv', {})
    end

    it 'should reject pipes' do
      command = 'ls /some/missing/path1 | grep path1'
      expect{ @env.run_command(command) }.to raise_error("Internal error: Invalid pipe '|' in spawn command: <ls /some/missing/path1 | grep path1>")
    end

    it 'returns true when command succeeeds' do
      command = "ls #{__FILE__}"
      expect( @env.execute(command) ).to eq true
    end

    it 'returns false when command fails and ignore_failure is false' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @env.execute(command) ).to eq false
    end

    it 'returns true when command fails and ignore_failure is true' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @env.execute(command, true) ).to eq true
    end
  end

  context 'with abstract methods' do
    subject(:described_object) { described_class.new(:puppet, 'acceptable_name', {}) }

    let(:regex) { %r{Implement .[a-z_]+ in a subclass} }

    %i[create fix update validate remove].each do |action|
      describe "##{action}" do
        it { expect { described_object.create }.to raise_error(NotImplementedError, regex) }
      end
    end
  end
end
