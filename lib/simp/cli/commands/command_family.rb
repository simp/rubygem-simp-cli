# frozen_string_literal: true

require 'simp/cli/commands/command'

# This class is the API for a Command Family.
class Simp::Cli::Commands::CommandFamily < Simp::Cli::Commands::Command
  # @return [String] "snake-case" name of command
  def snakecase_name
    self.class.to_s.split('::').last.gsub(%r{(?<!^)[A-Z]}) { "_#{$&}" }.downcase
  end

  # @return [Hash<Simp::Cli::Commands::Command>] memoized hash of sub commands
  def sub_commands
    return @sub_commands if @sub_commands

    @sub_commands = {}

    self.class.constants.each do |constant|
      obj = self.class.const_get(constant)
      next unless obj.ancestors.include? Simp::Cli::Commands::Command

      cmd = constant.to_s.gsub(%r{(?<!^)[A-Z]}) { "_#{$&}" }.downcase
      @sub_commands[cmd] = obj
    end
    @sub_commands
  end

  # @return [String] list of subcommands and their descriptions
  def subcommand_list
    max_chars = sub_commands.keys.map(&:size).max
    sub_commands.map do |cmd_name, cmd|
      "    #{cmd_name.ljust(max_chars + 4)} #{cmd.description}"
    end.join("\n")
  end

  # Run the command's `--help` action
  def help
    parse_command_line(['--help'])
  end

  # Run sub-command or provide help
  def run(args)
    sub_args = parse_command_line(args)
    return if @help_requested

    cmd = sub_args.shift
    if @sub_commands.key?(cmd)
      sub_cmd = @sub_commands[cmd].new
      sub_cmd.run(sub_args)
    else
      help

      if cmd || !args.empty?
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: Did not recognize '#{cmd} #{args.join(' ')}'"
        )
      end

      fail(Simp::Cli::ProcessingError, 'ERROR: Did not provide sub-command')
    end
  end

  # Parse command-line options for the command
  #   (Leaves sub-command options alone)
  # @param args [Array<String>] ARGV-style args array
  # @return [Array<String>] sub-command and its args
  def parse_command_line(args)
    opt_parser = OptionParser.new do |opts|
      opts.banner = "\n#{banner}"
      opts.separator <<-HELP_MSG.gsub(%r{^ {8}}, '')

        #{description}

        Usage:

          simp #{snakecase_name} -h
          simp #{snakecase_name} SUB-COMMAND -h
          simp #{snakecase_name} SUB-COMMAND [sub-command options]

        Sub-commands:

        #{subcommand_list}

        Options:

      HELP_MSG

      opts.on('-h', '--help', 'Print this message') do
        puts opts, ''
        @help_requested = true
      end
    end
    opt_parser.order!(args)
  end
end
