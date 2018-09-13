require 'simp/cli/defaults'
require 'simp/cli/errors'
require 'simp/cli/utils'

require 'highline'
HighLine.colorize_strings

module Simp; end
class Simp::Cli; end
module Simp::Cli::Commands; end

# This class is the API for a Command.  The derived class must
# implement a help() method and a run() method.
class Simp::Cli::Commands::Command

  # The derived class must implement this method and raise
  # an exception upon failure.
  def help
    raise("help() not implemented by #{self.class} ")
  end

  # The derived class must implement this method and raise
  # an exception upon failure.
  # +args+:: Command line arguments array
  def run(args = [])
    raise("run() not implemented by #{self.class} ")
  end
end
