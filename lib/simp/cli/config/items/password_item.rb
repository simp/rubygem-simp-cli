require_relative 'item'
require 'simp/cli/utils'

module Simp::Cli::Config


  # An Item that asks for Passwords, with:
  #   - special validation
  #   - invisible input
  #   - optional password generation
  class PasswordItem < Item
    attr_accessor :generate_option
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      # :never_generate         = don't give user option to auto-generate
      # :generate_no_query      = auto-generate and accept; should only be used when
      #                           a password will be persisted to hieradata
      # :generate_as_default    = ask user if they want to auto-generate, defaulting to 'yes',
      #                           and tell user to persist the password themselves
      # :no_generate_as_default = ask user if they want to auto-generate, defaulting to 'no',
      #                           and tell user to persist the password themselves
      @generate_option          = :generate_as_default
      @password_name            = nil # password name used in the auto-generate query;
                                      # When log level is > info and the explanatory
                                      # text about the password is not logged, this
                                      # is what tells the user which password the
                                      # query is for.  If unset, @key will be used
                                      # instead.
      @minimize_queries         = false # whether the user wants to use the minimum
                                        # number of queries as possible
    end


    def determine_value_without_override(allow_queries, force_defaults)
      @minimize_queries = force_defaults
      super
    end

    # returns the default answer to Item for noninteractive operations
    def default_value_noninteractive
      case @generate_option
      when :never_generate, :no_generate_as_default, :generate_as_default
        value = nil
      when :generate_no_query
        password = Simp::Cli::Utils.generate_password
        value = encrypt(password)
      end
      value
    end


    def query_extras( q )
      q.echo = '*'     # don't print password characters to stdout
    end


    def encrypt( password, salt=nil )
      notice('WARNING: password not encrypted; override in child class')
      password
    end


    # returns generated password or nil, if auto-generation is not
    # appropriate
    def auto_generate_password
      case @generate_option
      when :never_generate
        return nil
      when :generate_no_query
        # Normally, :generate_no_query goes hand-in-hand with skipping
        # the query.  However, if the Item's value was pre-assigned
        # and invalid, @skip_query will be set to false. This is so we
        # give the user an opportunity to fix the problem via a query.
        if @skip_query
          return Simp::Cli::Utils.generate_password
        else
          auto_default = 'yes'
        end
      when :generate_as_default
        auto_default = 'yes'
      when :no_generate_as_default
        auto_default = 'no'
      end

      if @minimize_queries
        # skip the 'Auto-generate the password?' query
        if auto_default == 'no'
          # assume auto-generation is not appropriate
          return nil
        else
          # assume auto-generation is appropriate
          password = generate_and_print_password
        end
      else
        password = nil
        @password_name = @key if @password_name.nil? or @password_name.empty?
        if agree( "Auto-generate the #{@password_name} password? " ){ |q| q.default = auto_default }
          password = generate_and_print_password
        end
      end
      password
    end

    # generate a password, print it to the screen, and make user
    # acknowledge the password by pressing <enter>
    def generate_and_print_password
      password = Simp::Cli::Utils.generate_password
      logger.say ('~'*80).green + "\n"
      logger.say 'NOTE: '.green.bold + " The generated password is: \n\n"
      logger.say '   ' + password.yellow.bold + "\n\n"
      logger.say '  >>>> Please remember this password! <<<<'.bold
      logger.say '   It will ' + '**NOT**'.bold + ' be written to the log or hieradata.'
      logger.say ('~'*80).green + "\n"
      logger.say '*** Press enter to continue ***'.cyan.bold.blink
      ask ''
      password
    end


    def not_valid_message
      # The failure message has already logged, but if we return nil
      # the entire description will be spewed.  So, use a single
      # space, which will appear at the beginning of the re-prompt,
      # because HighLine thinks a space means no newline.
      ' '
    end

    # ask for the password twice (and verify that both match)
    def query_ask
      password = nil

      # auto-generate the password, if appropriate
      password = auto_generate_password

      unless password
        # have to query user for value
        retries = 5
        begin
          if retries == 0
            err_msg  = "FATAL: Too many failed attempts to enter password for #{@key}"
            raise Simp::Cli::ProcessingError.new(err_msg)
          end

          # use Item::query_ask to read in, validate, and re-prompt if necessary
          # to get a valid password
          logger.say "Please enter a password:"
          password = super

          # use HighLine to read in the confirm password, but don't do any
          # validation, here
          logger.say "Please confirm the password:"
          confirm_password = ask( "<%= color('Confirm #{query_prompt}', WHITE, BOLD) %>: ",
                  highline_question_type ) do |q|
            q.echo = '*'
            q
          end

          # restart the process if the confirm password does not match the
          # validated password.
          if password != confirm_password
            raise Simp::Cli::PasswordError.new('WARNING: Passwords did not match!  Please try again.')
          end
        rescue Simp::Cli::PasswordError => e
          logger.say(e.message.yellow)
          retries -= 1
          retry
        end
      end

      encrypt password
    end


    def validate x
      result = true
      begin
        Simp::Cli::Utils.validate_password x
      rescue Simp::Cli::PasswordError => e
        warn('WARNING: ', [:YELLOW, :BOLD], e.message, [:YELLOW])
        result = false
      end
      result
    end

  end
end
