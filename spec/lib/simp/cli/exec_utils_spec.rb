# frozen_string_literal: true

require 'simp/cli/exec_utils'
require 'spec_helper'

class LocalTestLogger
  attr_accessor :trace_msgs, :debug_msgs, :info_msgs,
                :notice_msgs, :error_msgs, :fatal_msgs

  def initialize
    @trace_msgs = []
    @debug_msgs = []
    @info_msgs = []
    @notice_msgs = []
    @error_msgs = []
    @fatal_msgs = []
  end

  def trace(msg)
    @trace_msgs << msg
  end

  def debug(msg)
    @debug_msgs << msg
  end

  def info(msg)
    @info_msgs << msg
  end

  def notice(msg)
    @notice_msgs << msg
  end

  def error(msg)
    @error_msgs << msg
  end

  def fatal(msg)
    @fatal_msgs << msg
  end
end

describe Simp::Cli::ExecUtils do
  before :each do
    @logger = LocalTestLogger.new
  end

  describe '.run_command' do
    it 'rejects pipes' do
      command = 'ls /some/missing/path1 | grep path1'
      expect { described_class.run_command(command) }.to raise_error("Internal error: Invalid pipe '|' in spawn command: <ls /some/missing/path1 | grep path1>")
    end

    it 'returns successful status when command succeeeds' do
      command = "ls #{__FILE__}"
      expect(described_class.run_command(command)[:status]).to be true
      expect(described_class.run_command(command)[:stdout]).to match __FILE__
      expect(described_class.run_command(command)[:stderr]).to eq ''

      described_class.run_command(command, false, @logger)
      expect(@logger.debug_msgs.size).to eq 1
      expect(@logger.debug_msgs[0]).to eq "Executing: #{command}"
    end

    it 'returns failed status when command fails and ignore_failure is false' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect(described_class.run_command(command)[:status]).to be false
      expect(described_class.run_command(command)[:stdout]).to eq ''
      expect(described_class.run_command(command)[:stderr]).to match(%r{ls: cannot access.*/some/missing/path1.*: No such file or directory})

      described_class.run_command(command, false, @logger)
      expect(@logger.error_msgs).not_to be_empty
      expect(@logger.error_msgs[0]).to match(%r{\[#{command}\] failed with exit status})
      expect(@logger.error_msgs[1]).to match(%r{ls: cannot access.*/some/missing/path1.*: No such file or directory})
    end

    it 'returns successful status when command fails and ignore_failure is true' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect(described_class.run_command(command, true)[:status]).to be true
      expect(described_class.run_command(command)[:stdout]).to eq ''
      expect(described_class.run_command(command)[:stderr]).to match(%r{ls: cannot access.*/some/missing/path1.*: No such file or directory})

      described_class.run_command(command, true, @logger)
      expect(@logger.error_msgs).to be_empty
    end
  end

  describe '.execute' do
    it 'rejects pipes' do
      command = 'ls /some/missing/path1 | grep path1'
      expect { described_class.run_command(command) }.to raise_error("Internal error: Invalid pipe '|' in spawn command: <ls /some/missing/path1 | grep path1>")
    end

    it 'returns true when command succeeeds' do
      command = "ls #{__FILE__}"
      expect(described_class.execute(command)).to be true
      described_class.execute(command, false, @logger)
      expect(@logger.debug_msgs.size).to eq 1
      expect(@logger.debug_msgs[0]).to eq "Executing: #{command}"
    end

    it 'returns false when command fails and ignore_failure is false' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect(described_class.execute(command)).to be false
    end

    it 'returns true when command fails and ignore_failure is true' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect(described_class.execute(command, true)).to be true

      described_class.execute(command, true, @logger)
      expect(@logger.error_msgs).to be_empty
    end
  end
end
