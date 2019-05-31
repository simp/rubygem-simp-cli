# frozen_string_literal: true

require 'simp/cli/commands/command_family'

# Helper utility to maintain local SIMP Puppetfiles
class Simp::Cli::Commands::Puppetfile < Simp::Cli::Commands::CommandFamily
  def banner
    '=== The SIMP Puppetfile Tool ==='
  end

  def description
    'Helper utility to maintain local SIMP Puppetfiles'
  end
end
