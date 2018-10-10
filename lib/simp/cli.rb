$LOAD_PATH << File.expand_path( '..', File.dirname(__FILE__) )

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
    puts 'Usage: simp [command]'
    puts
    puts '  Commands'
    @commands.keys.sort.each do |command_name|
      puts "    - #{command_name}"
    end
    puts '    - help [command]'
    puts
  end

  def self.version
    cmd = 'rpm -q simp'
    begin
      `#{cmd}`.split(/\n/).last.match(/([0-9]+\.[0-9]+\.?[0-9]*)/)[1]
    rescue
      #TODO Send this message to stderr instead of stdout?
      msg = "Cannot find SIMP OS installation via `#{cmd}`!"
      say 'WARNING: '.bold.yellow + msg.yellow
    end
  end

  def self.start(args = ARGV)
    # grab the classes that are simp commands
    @commands = {}
    Simp::Cli::Commands::constants.each{ |constant|
      obj = Simp::Cli::Commands.const_get(constant)
      if obj.respond_to?(:superclass) and obj.superclass == Simp::Cli::Commands::Command
        @commands[constant.to_s.downcase] = obj.new
      end
    }
    @commands['version'] = self

    result = 0
    if args.length == 0 or (args.length == 1 and args[0] == 'help')
      menu
    elsif args[0] == 'version'
      puts version
    elsif args[0] == 'help'
      if (command = @commands[args[1]]).nil?
        $stderr.puts "\n#{args[1]} is not a recognized command\n\n".red
        menu
        result = 1
      elsif args[1] == 'version'
        puts 'Display the current version of SIMP.'
      else
        command.help
      end
    elsif (command = @commands[args[0]]).nil?
      $stderr.puts "\n#{args[0]} is not a recognized command\n\n".red
      menu
      result = 1
    else
      begin
        # command.run() expected to raise exception upon failure
        command_name = args[0]
        command.run(args.drop(1))
      rescue OptionParser::ParseError => e
        $stderr.puts "'#{command_name}' command options error: #{e.message}\n\n".red
        result = 1
      rescue EOFError
        # user has terminated an interactive query
        $stderr.puts "\nInput terminated! Exiting.\n".red
        result = 1
      rescue SignalException => e
        # SignalException is a bit messy.
        # - SIGINT
        #   Ruby 1.8.7                                 Ruby > 1.8.7
        #   e.inspect -> 'Interrupt'                   e.inspect -> 'Interrupt'
        #   e.signo   -> nil                           e.signo   -> 2
        #   e.message -> nil                           e.message -> nil
        # - All other signals
        #   Ruby 1.8.7                                 Ruby > 1.8.7
        #   e.inspect -> '#<SignalException: SIGxxx>'  e.inspect -> '#<SignalException: SIGxxx>'
        #   e.signo   -> nil                           e.signo   -> <signal number>
        #   e.message -> 'SIGxxx'                      e.message -> 'SIGxxx'
        if e.inspect == 'Interrupt'
          $stderr.puts "\nProcessing interrupted! Exiting.\n\n".red
        else
          $stderr.puts "\nProcess received signal #{e.message}. Exiting!\n\n".red
          e.backtrace.first(10).each{|l| $stderr.puts l }
        end
        result = 1
      rescue Simp::Cli::ProcessingError => e
        $stderr.puts "\n#{e.message}\n\n".red
        result = 1
      rescue => e
        $stderr.puts "\n#{e.message}\n\n".red
        e.backtrace.first(10).each{|l| $stderr.puts l }
        result = 1
      end
    end
    return result
  end
end
