require 'simp/cli/commands/command'

class Simp::Cli::Commands::Doc < Simp::Cli::Commands::Command

  def description
    'Show SIMP documentation in elinks'
  end

  def help
    puts <<EOM

=== The SIMP Doc Tool ===
Show SIMP documentation in elinks, a text-based web browser

Usage:  simp doc

EOM
  end

  def run(args)
    parse_command_line(args)
    return if @help_requested

    unless system("rpm -q --quiet simp-doc")
      err_msg = "Package 'simp-doc' is not installed, cannot continue."
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    main_page = %x{rpm -ql simp-doc | grep html/index.html$ | head -1}.strip.chomp

    unless File.exists?(main_page)
      err_msg = "Could not find the SIMP documentation. Please ensure that you can access '#{main_page}'."
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    exec("links #{main_page}")
  end

  def parse_command_line(args)
    if args.include?('-h') or args.include?('--help')
      help
      @help_requested = true
    elsif args.size > 0
      raise OptionParser::ParseError.new("Unsupported option: #{args.first}")
    end
  end
end
