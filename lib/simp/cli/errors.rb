module Simp; end

class Simp::Cli
  # Any command processing error that terminates the command
  # operation but for which a backtrace is not required
  class ProcessingError < StandardError; end
end

