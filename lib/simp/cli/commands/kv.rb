# frozen_string_literal: true

require 'simp/cli/commands/command_family'

class Simp::Cli::Commands::Kv < Simp::Cli::Commands::CommandFamily
  def banner
    '=== The SIMP Key/Value Store Tool ==='
  end

  def description
    'Utility to inspect and manage content in key/value stores'
  end
end
