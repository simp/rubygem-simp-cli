require File.expand_path( 'item', File.dirname(__FILE__) )
require 'simp/cli/lib/utils'

module Simp::Cli::Config


  # An Item that asks for Passwords, with:
  #   - special validation
  #   - invisible input
  #   - optional password generation
  class PasswordItem < Item
    attr_accessor :generate_option
    def initialize
      super
      # :never_generate         = don't give user option to auto-generate
      # :generate_no_query      = auto-generate and accept
      # :generate_as_default    = ask user if they want to auto-generate, defaulting to 'yes'
      # :no_generate_as_default = ask user if they want to auto-generate, defaulting to 'no'
      @generate_option          = :generate_as_default
      @password_name            = nil # password name used in the auto-generate query;
                                      # When log level is > info and the explanatory
                                      # text about the password is not logged, this
                                      # is what tells the user which password the
                                      # query is for.  If unset, @key will be used
                                      # instead.
    end

    # returns the default answer to Item for noninteractive operations
    def default_value_noninteractive
      case @generate_option
      when :never_generate, :no_generate_as_default
        value = nil
      when :generate_no_query, :generate_as_default
        password = Simp::Cli::Config::Utils.generate_password
        value = encrypt(password)
      end
      value
    end


    def query_extras( q )
      q.echo = '*'     # don't print password characters to stdout
    end


    def encrypt( password, salt=nil )
      info 'WARNING: password not encrypted; override in child class'
      password
    end


    def query_generate_password
      case @generate_option
      when :never_generate
        return false
      when :generate_no_query
        # Normally, :generate_no_query goes hand-in-hand with skipping
        # the query.  However, if the Item's value was pre-assigned
        # and invalid, @skip_query will be set to false. This is so we
        # give the user an opportunity to fix the problem via a query.
        if @skip_query
          return Simp::Cli::Config::Utils.generate_password
        else
          default = 'yes'
        end
      when :generate_as_default
        default = 'yes'
      when :no_generate_as_default
        default = 'no'
      end

      password = false
      @password_name = @key if @password_name.nil? or @password_name.empty?
      if agree( "Auto-generate the #{@password_name} password? " ){ |q| q.default = default }
        password = Simp::Cli::Config::Utils.generate_password
        logger.say "<%= color( '#{''.ljust(80,'-')}', GREEN)%>\n"
        logger.say "<%= color( 'NOTE: ', GREEN, BOLD)%>" +
            "<%= color( ' the generated password is: ') %>\n"
        logger.say "\n"
        # since we are using {} as the string delimiter, make sure we've escaped
        # any {} in the password
        escaped_password = password.dup
        escaped_password.gsub!('{', '\{')
        escaped_password.gsub!('}', '\}')
        logger.say "<%= color( %q{   #{escaped_password}}, YELLOW, BOLD )%>  "
        logger.say "\n"
        logger.say "\n"
        logger.say 'Please remember it!'
        logger.say "<%= color( '#{''.ljust(80,'-')}', GREEN)%>\n"
        logger.say "<%= color( '*** Press enter to continue ***', CYAN, BOLD, BLINK ) %>\n"
        ask ''
      end
      password
    end


    # ask for the password twice (and verify that both match)
    def query_ask
      password = false
      password = query_generate_password unless @generate_option == :never_generate

      while !password
        answers = []
        [0,1].each{ |x|
          logger.say "Please enter a password:"     if x == 0
          logger.say "Please confirm the password:" if x == 1
          answers[x] = super
        }
        if answers.first == answers.last
          password = answers.first
        else
          say_yellow( 'WARNING: passwords did not match!  Please try again.' )
        end
      end

      encrypt password
    end


    def validate x
      result = true
      begin
        Simp::Cli::Config::Utils.validate_password x
      rescue Simp::Cli::Config::PasswordError => e
        warn('WARNING: ', [:YELLOW, :BOLD], e.message, [:YELLOW])
        result = false
      end
      result
    end

    def say_yellow( msg, options=[] )
      options = options.unshift( '' ) unless options.empty?
      # since we are using {} as the string delimiter, make sure we've escaped
      # any {} in the message
      escaped_msg = msg.dup
      escaped_msg.gsub!('{', '\{')
      escaped_msg.gsub!('}', '\}')
      logger.say("<%= color(%q{#{escaped_msg}}, YELLOW #{options.join(', ')}) %>\n")
    end

  end
end
