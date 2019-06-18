require 'simp/cli/errors'
require 'highline/import'
HighLine.colorize_strings  # for red() method added to String

module Simp; end
class Simp::Cli; end
module Simp::Cli::ExecUtils

    # Execute a command in a child process, log failure and return
    # a hash with the command status, stdout and stderr.
    #
    # +command+:  Command to be executed
    #
    # +ignore_failure+:  Whether to ignore failures.  When true and
    #   and the command fails, does not log the failure and returns
    #   a hash with :status = true
    #
    # +logger+:  Optional Simp::Cli::Logging::Logger object. When not
    #    set, logging is suppressed.
    #
    def self.run_command(command, ignore_failure = false, logger = nil)
      logger.debug( "Executing: #{command}" ) if logger
      # We noticed inconsistent behavior when spawning commands
      # with pipes, particularly a pipe to 'xargs'. Rejecting pipes
      # for now, but we may need to re-evaluate in the future.
      raise Simp::Cli::InvalidSpawnError.new(command) if command.include? '|'
      out_pipe_r, out_pipe_w = IO.pipe
      err_pipe_r, err_pipe_w = IO.pipe
      pid = spawn(command, :out => out_pipe_w, :err => err_pipe_w)
      out_pipe_w.close
      err_pipe_w.close

      Process.wait(pid)
      exitstatus = $?.nil? ? nil : $?.exitstatus
      stdout = out_pipe_r.read
      out_pipe_r.close
      stderr = err_pipe_r.read
      err_pipe_r.close

      return {:status => true, :stdout => stdout, :stderr => stderr} if ignore_failure

      if exitstatus == 0
        return {:status => true, :stdout => stdout, :stderr => stderr}
      else
        logger.error( "\n[#{command}] failed with exit status #{exitstatus}:".red ) if logger
        stderr.split("\n").each do |line|
          logger.error( (' '*2 + line).red ) if logger
        end
        return {:status => false, :stdout => stdout, :stderr => stderr}
      end
    end

    # Execute a command in a child process, log failure and return
    # whether the command succeeded
    #
    # +command+:  Command to be executed
    #
    # +ignore_failure+:  Whether to ignore failures.  When true and
    #   the command fails, does not log the failure and returns true.
    #
    # +logger+:  Optional Simp::Cli::Logging::Logger object.
    #    When not set, logging is suppressed.
    def self.execute(command, ignore_failure = false, logger = nil)
      return run_command(command, ignore_failure, logger)[:status]
    end
end

