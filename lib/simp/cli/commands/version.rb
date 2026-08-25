# frozen_string_literal: true

require 'simp/cli/commands/command'

class Simp::Cli::Commands::Version < Simp::Cli::Commands::Command
  def description
    'Display the current version of SIMP'
  end

  def help
    puts "\n#{description}\n\nUSAGE:  simp version\n\n"
  end

  def run(args)
    parse_command_line(args)
    return if @help_requested

    cmd = 'rpm -q simp'
    begin
      puts `#{cmd}`.split("\n").last.match(%r{([0-9]+\.[0-9]+\.?[0-9]*)})[1]
    rescue StandardError
      msg = 'Version unknown:'
      msg += "  Cannot find SIMP OS installation via `#{cmd}`!"
      raise Simp::Cli::ProcessingError, msg
    end
  end

  def parse_command_line(args)
    if args.include?('-h') || args.include?('--help')
      help
      @help_requested = true
    elsif args.size.positive?
      raise OptionParser::ParseError, "Unsupported option: #{args.first}"
    end
  end
end
