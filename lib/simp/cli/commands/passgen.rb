# frozen_string_literal: true

require 'simp/cli/commands/command_family'

class Simp::Cli::Commands::Passgen < Simp::Cli::Commands::CommandFamily

  def banner
    '=== The SIMP Password Tool ==='
  end

  def description
    "Utility to inspect and manage 'simplib::passgen' passwords"
  end
end
