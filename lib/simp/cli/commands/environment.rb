require 'simp/cli/commands/command_family'

# Helper utility to maintain SIMP Environments
class Simp::Cli::Commands::Environment < Simp::Cli::Commands::CommandFamily

  # @return the banner to be displayed with the command help
  def banner
    "=== The SIMP Environment Tool ==="
  end

  # @return [String] description to be displayed with the command help
  def description
    'Utility to manage and coordinate SIMP omni-environments'
  end
end
