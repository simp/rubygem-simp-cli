require 'simp/cli/commands/command'

class Simp::Cli::Commands::Version < Simp::Cli::Commands::Command

  def description
    'Display the current version of SIMP.'
  end

  def help
    puts "\n#{description}\n\nUsage:  simp version\n"
  end

  def run(args)
    parse_command_line(args)
    return if @help_requested

    cmd = 'rpm -q simp'
    begin
      puts `#{cmd}`.split(/\n/).last.match(/([0-9]+\.[0-9]+\.?[0-9]*)/)[1]
    rescue
      msg = 'Version unknown:'
      msg += "  Cannot find SIMP OS installation via `#{cmd}`!"
      raise Simp::Cli::ProcessingError.new(msg)
    end
  end

  def parse_command_line(args)
    if args.include?('-h') or args.include?('--help')
      puts help
      @help_requested = true
    elsif args.size > 0
      raise OptionParser::ParseError.new("Unsupported option: #{args.first}")
    end
  end

end
