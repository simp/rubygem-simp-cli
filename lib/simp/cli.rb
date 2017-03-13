$LOAD_PATH << File.expand_path( '..', File.dirname(__FILE__) )

require 'optparse'

require 'simp/cli/version'
require 'simp/cli/lib/utils'
require 'simp/cli/lib/libkv'

# load each command
commands_path = File.expand_path( 'cli/commands/*.rb', File.dirname(__FILE__) )

# load the commands from commands/*.rb and grab the classes that are simp commands
Dir.glob( commands_path ).sort_by(&:to_s).each do |command_file|
    require command_file
end

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

  def self.help  # <-- lol.
    puts @opt_parser.to_s
  end

  def self.run(args)
     @opt_parser.parse!(args)
  end

  private
  def self.version
    cmd = 'rpm -q simp'
    begin
      `#{cmd}`.split(/\n/).last.match(/([0-9]+\.[0-9]+\.?[0-9]*)/)[1]
    rescue
      #TODO Send this message to stderr instead of stdout?
      msg = "Cannot find SIMP OS installation via `#{cmd}`!"
      say '<%= color( "WARNING: ", BOLD, YELLOW ) %>' +
          "<%= color( '#{msg}', YELLOW) %>"
    end
  end

  def self.start(args = ARGV)
    # grab the classes that are simp commands
    @commands = {}
    Simp::Cli::Commands::constants.each{ |constant|
      obj = Simp::Cli::Commands.const_get(constant)
      if obj.respond_to?(:superclass) and obj.superclass == Simp::Cli
        @commands[constant.to_s.downcase] = obj
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
        $stderr.puts "\n\033[31m#{args[1]} is not a recognized command\033[39m\n\n"
        menu
        result = 1
      elsif args[1] == 'version'
        puts "Display the current version of SIMP."
      else
        command.help
      end
    elsif (command = @commands[args[0]]).nil?
      $stderr.puts "\n\033[31m#{args[0]} is not a recognized command\033[39m\n\n"
      menu
      result = 1
    else
      begin
        # command.run() expected to raise exception upon failure
        command_name = args[0]
        command.run(args.drop(1))
      rescue OptionParser::ParseError => e
        $stderr.puts "\033[31m'#{command_name}' command options error: #{e.message}\033[39m\n\n"
        result = 1
      rescue EOFError
        # user has terminated an interactive query
        $stderr.puts "\n\033[31mInput terminated! Exiting.\033[39m\n"
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
          $stderr.puts "\n\033[31mProcessing interrupted! Exiting.\033[39m\n\n"
        else
          $stderr.puts "\n\033[31mProcess received signal #{e.message}. Exiting!\033[39m\n\n"
          e.backtrace.first(10).each{|l| $stderr.puts l }
        end
        result = 1
      rescue => e
        $stderr.puts "\n\033[31m#{e.message}\033[39m\n\n"
        e.backtrace.first(10).each{|l| $stderr.puts l }
        result = 1
      end
    end
    return result
  end
end
