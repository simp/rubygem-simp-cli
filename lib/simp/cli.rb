# frozen_string_literal: true

$LOAD_PATH << File.expand_path('..', __dir__)

require 'optparse'
require 'highline'
HighLine.colorize_strings

require 'simp/cli/commands'
require 'simp/cli/errors'
require 'simp/cli/utils'
require 'simp/cli/version'

# namespace for SIMP logic
module Simp; end

# namespace for SIMP CLI commands
class Simp::Cli
  def self.menu
    puts 'SIMP Command Line Interface'
    puts
    puts 'USAGE:'
    puts ' simp -h'
    puts ' simp COMMAND -h'
    puts ' simp COMMAND [command options]'
    puts
    puts 'COMMANDS:'
    command_array = @commands.sort
    max_length = command_array.map { |command, _command_obj| command.length }.max
    command_array.each do |command, command_obj|
      puts "  #{command.ljust(max_length, ' ')}   #{command_obj.description}"
    end
    puts
  end

  def self.start(args = ARGV)
    # grab the classes that are simp commands
    @commands = {}
    Simp::Cli::Commands.constants.each do |constant|
      next if (constant == :Command) || (constant == :CommandFamily)

      obj = Simp::Cli::Commands.const_get(constant)
      if obj.ancestors.include? Simp::Cli::Commands::Command
        @commands[constant.to_s.downcase] = obj.new
      end
    end

    result = 0
    help_args = [
      '-h',
      '--help',
    ]
    if args.empty? || args[0] == 'help' ||
       (args.length == 1 && help_args.include?(args[0]))
      menu
    elsif (command = @commands[args[0]]).nil?
      warn "\n#{args[0]} is not a recognized command\n\n".red
      menu
      result = 1
    else
      begin
        # command.run() expected to raise exception upon failure
        command_name = args[0]
        command.run(args.drop(1))
      rescue OptionParser::ParseError => e
        warn "'#{command_name}' command options error: #{e.message}\n\n".red
        result = 1
      rescue EOFError
        # user has terminated an interactive query
        warn "\nInput terminated! Exiting.\n".red
        result = 1
      rescue Interrupt
        warn "\nProcessing interrupted! Exiting.\n\n".red
        result = 1
      rescue SignalException => e
        warn "\nProcess received signal #{e.message}. Exiting!\n\n".red
        e.backtrace.first(10).each { |l| warn l }
        result = 1
      rescue Simp::Cli::ProcessingError => e
        warn "\n#{e.message}\n\n".red
        result = 1
      rescue StandardError => e
        warn "\n#{e.message}\n\n".red
        e.backtrace.first(10).each { |l| warn l }
        result = 1
      end
    end
    result
  end
end
