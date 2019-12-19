# frozen_string_literal: true

require 'simp/cli/commands/command_family'

class Simp::Cli::Commands::Puppetfile < Simp::Cli::Commands::CommandFamily
  def banner
    '=== The SIMP Puppetfile Tool ==='
  end

  def description
    'Utility to maintain local SIMP Puppetfiles'
  end
end
