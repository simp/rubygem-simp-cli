module Simp; end

class Simp::Cli
  # Any command processing error that terminates the command
  # operation but for which a backtrace is not required
  class ProcessingError < StandardError; end

  # Password fails to validate
  class PasswordError < StandardError; end

  # Invalid spawn command
  class InvalidSpawnError < StandardError;
    def initialize(cmd)
      super("Internal error: Invalid pipe '|' in spawn command: <#{cmd}>")
    end
  end

end

