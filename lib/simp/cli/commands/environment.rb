require 'simp/cli/commands/command_family'

# Helper utility to maintain local SIMP Environments
class Simp::Cli::Commands::Environment < Simp::Cli::Commands::CommandFamily
  # @return [String] description of command
  def self.description
    'Manage and coordinate SIMP omni-environments'
  end
end
