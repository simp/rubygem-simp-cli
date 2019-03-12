require 'simp/cli/commands/command'

# Helper utility to maintain local SIMP Puppetfiles
class Simp::Cli::Commands::Puppetfile < Simp::Cli::Commands::Command
  # Load sub-commands
  def initialize
    @sub_commands = {}
    subcmd_files = Dir.glob(File.expand_path('puppetfile/*.rb',__dir__)).sort_by(&:to_s)
    subcmd_files.each { |file| require file }
    Simp::Cli::Commands::Puppetfile::constants.each do |constant|
      cmd = constant.to_s.downcase
      @sub_commands[cmd] = Simp::Cli::Commands::Puppetfile.const_get(constant)
    end
  end

  # @return [String] list of subcommands and their descriptions
  def subcommand_list
    max_chars = @sub_commands.keys.map{|x| x.size}.max
    @sub_commands.map do |cmd_name,cmd|
      "    #{cmd_name.ljust(max_chars + 4)} #{cmd.description}"
    end.join("\n")
  end

  # Run sub-command or provide help
  def run(args)
    sub_args = parse_command_line(args)
    cmd = sub_args.shift
    if @sub_commands.keys.include?(cmd)
      puts "\n=== PUPPETFILE COMMAND: '#{cmd}'\n\n"
      sub_cmd = @sub_commands[cmd].new
      sub_cmd.run(sub_args)
    else
      if cmd || args.size > 0
        warn("Did not recognize '#{cmd} #{args.join(' ')}'")
      else
        warn("Did not provide sub-command")
      end

      help
    end
  end

  # Run the command's `--help` action
  def help
    parse_command_line( [ '--help' ] )
  end


  # Parse command-line options for the command
  #   (Leaves sub-command options alone)
  # @param args [Array<String>] ARGV-style args array
  # @return [Array<String>] sub-command and its args
  def parse_command_line(args)
    opt_parser = OptionParser.new do |opts|
      opts.banner = "\n=== The SIMP Puppetfile Tool ==="
      opts.separator <<-HELP_MSG.gsub(%r{^ {8}}, '')

        Helper utility to maintain local SIMP Puppetfiles

        Usage:

          simp puppetfile [options] SUB-COMMAND [sub-command options]

        Sub-commands:

        #{subcommand_list}

        Options:

      HELP_MSG

      opts.on('-h', '--help', 'Print this message') do
        puts opts, ''
        exit
      end
    end
    opt_parser.order!(args)
  end

end
