require 'highline/import'
require 'puppet'
require 'yaml'
require 'simp/cli/config/errors'
require 'simp/cli/logging'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config

  class Item

    include Simp::Cli::Logging

    PAUSE_SECONDS = 2 # number of seconds to pause processing to allow
                      # an important logged message to be highlighted
                      # on the screen

    attr_reader   :key, :description, :data_type, :fact, :puppet_apply_cmd
    attr_accessor :value
    attr_accessor :start_time
    attr_accessor :skip_query, :skip_yaml, :silent
    attr_accessor :config_items
    attr_accessor :next_items_tree

    # Derive Item classes must set @key
    def initialize
      @key               = nil           # answers file key for the config Item
      @value             = nil           # value (decided by user)
      @value_os          = nil           # value extracted from the system
      @value_recommended = nil           # best default value
      @description       = nil           # A text description of the Item
      @data_type         = :global_hiera # :internal     = parameter used within simp config,
                                         #                 but not persisted anywhere
                                         # :cli_params   = parameter persisted to answers YAML
                                         #                 file for use by simp config
                                         # :global_hiera = parameter persisted to hieradata YAML
                                         #                 file for use by SIMP clients
                                         #                 and server
                                         # :global_class = class added to class list in
                                         #                 hieradata YAML file for use
                                         #                 by SIMP clients and server
                                         # :server_hiera = parameter persisted to hieradata YAML
                                         #                 file for use by SIMP server
                                         # :none         = carries no data (e.g., ActionItem)
                                         #
      @fact              = nil           # Facter fact to query OS value

      @start_time        = nil           # time at which simp config started; use for backup timestamp

      @skip_query        = false         # skip the query and use the default_value
      @skip_yaml         = false         # skip yaml output

      @silent            = false         # no output to stdout/HighLine/log
      @alt_source        = nil           # when set, non-query source of Item's value:
                                         #   :noninteractive = default value
                                         #   :answered       = pre-assigned value

      possible_module_paths = [
        '/usr/share/simp/modules',
        '/etc/puppetlabs/code/environments/simp/modules',
        '/etc/puppet/environments/simp/modules'
      ]

      possible_module_paths.each do |modpath|
        if File.directory?(modpath)
          @puppet_apply_cmd = "puppet apply --modulepath=#{modpath} "
          break
        end
      end

      @puppet_apply_cmd ||= 'puppet apply '

      @config_items      = {}          # a hash of all previous Config::Items
      # a Hash of additional Items whose value this Item may need to use.
      # The keys of the Hash are used to look up the queue
      # format:
      #   'answer1' => [ Item1, Item2, .. ]
      #   'answer2' => [ Item3, Item4, .. ]
      @next_items_tree   = {}
    end


    # --------------------------------------------------------------------------
    # general methods related to Item#value
    # --------------------------------------------------------------------------

    # whether this Item sets a data value
    def value_required?
      if @data_type == :none or @data_type == :global_class
        return false
      else
        return true
      end
    end

    # returns the value of item as read from OS
    # Value is cached in @value_os to avoid unnecessary re-evaluation.
    # Derived Items should override Item::get_os_value() to customize.
    def os_value
      if @value_os.nil?
        @value_os = get_os_value
      end
      @value_os
    end

    # returns the value of Item as read from OS (via Facter)
    # Derived Items can override to customize
    def get_os_value
      Facter.value( @fact ) unless @fact.nil?
    end

    # returns the value of Item as recommended by Very Clever Logic (tm)
    # Value is cached in @value_recommended to avoid unnecessary
    # re-evaluation.
    # Derived Items should override Item::get_recommended_value() to
    # customize.
    def recommended_value
      if @value_recommended.nil?
        @value_recommended = get_recommended_value
      end
      @value_recommended
    end

    def get_recommended_value; nil; end

    # returns the default displayed to the user in Item#query
    def default_value
      @value || recommended_value
    end

    # returns the default answer to Item for noninteractive operations
    # Derived Items must override this when the displayed value
    # returned by default_value() needs to be mapped to a final value
    # (e.g., 'yes'/'no' mapped to true/false).
    def default_value_noninteractive
      default_value
    end

    # --------------------------------------------------------------------------
    #  Pretty stdout/stdin methods
    # --------------------------------------------------------------------------

    # String in yaml answer file format, with comments (if any)
    def to_yaml_s
      raise InternalError.new( "@key is empty for #{self.class}" ) if "#{@key}".empty?

      x =  "=== #{@key} ===\n"
      x += "#{(description || 'FIXME: NO DESCRIPTION GIVEN')}\n"

      # comment every line that describes the item:
      x =  x.each_line.map{ |y| "# #{y}" }.join

      # add yaml (but stripped of frontmatter and first indent)
      # TODO: should we be using SafeYAML?  http://danieltao.com/safe_yaml/
      x += { @key => @value }.to_yaml.gsub(/^---\s*\n/m, '').gsub(/^  /, '' )
      x += "\n"

      if @skip_yaml
        nil
      else
        x
      end
    end

    # print a pretty banner to describe an item
    def print_banner
      info( "\n=== #{@key} ===", [:CYAN, :BOLD])
      info( description, [:CYAN] )
      # inspect is a work around for Ruby 1.8.7 Array.to_s garbage
      info( "    - os value:          #{os_value.inspect}", [:CYAN] )          if os_value
      info( "    - recommended value: #{recommended_value.inspect}", [:CYAN] ) if recommended_value
      info( "    - chosen value:      #{@value.inspect}"           , [:CYAN] ) if @value
    end


    # print a pretty summary of the Item's key+value
    def print_summary
      raise InternalError.new( "@key is empty for #{self.class}" ) if "#{@key}".empty?

      log_params = []
      log_params += [ "(#{@alt_source.to_s})", [:CYAN, :BOLD] ] unless @alt_source.nil?
      log_params += ["#{@key} = ", [], "#{@value.inspect}", [:BOLD] ]
      info(*log_params)
    end

    # --------------------------------------------------------------------------
    # methods to set Item#value
    # --------------------------------------------------------------------------

    # Determine the value of the object, querying the user or using the
    # default, as appropriate
    #
    # raises  Simp::Cli::Config::ValidationError upon failure
    def determine_value(allow_queries, force_defaults)
      # don't do anything with Items that don't carry data
      return unless value_required?

      if @skip_query and @value.nil?
        # value is supposed to be be automatically determined;
        # @skip_query is typically used to gather system settings or
        # for internal Items needed by other Items in the item decision
        # tree.
        determine_value_from_default()
      elsif @value.nil?
        # value has not been pre-assigned
        determine_value_without_override(allow_queries, force_defaults)
      else
        # value has been pre-assigned, but may not be valid
        determine_value_with_override(allow_queries, force_defaults)
      end

      print_summary
    end

    def determine_value_from_default
      # default value requires no validation
      @value = default_value_noninteractive
      @alt_source = :noninteractive
    end

    def determine_value_without_override(allow_queries, force_defaults)
      if !allow_queries and !force_defaults
        err_msg = "FATAL: No answer found for '#{@key}'"
        raise Simp::Cli::Config::ValidationError.new(err_msg)
      else
        if force_defaults
          # try to use the default value, which may or may not exist
          # NOTE: We intentionally set @value so validation logic
          # for encrypted passwords is exercised, for PasswordItems
          # that prompt for unencrypted values and then encrypt. These
          # Items exercise different validation logic for unencrypted
          # and encrypted values.
          @value = default_value_noninteractive
          if validate(@value)
            @alt_source = :noninteractive
          else
            @value.nil?
          end
        end
        if @value.nil?
          if allow_queries
            query
            @alt_source = nil
          else
            err_msg = "FATAL: No valid answer found for '#{@key}'"
            raise Simp::Cli::Config::ValidationError.new(err_msg)
          end
        end
      end
    end

    def determine_value_with_override(allow_queries, force_defaults)
      if validate(@value)
        @alt_source = :answered
      else
        # We don't expect users to override Items for which the user
        # would not be queried in an interactive run.  However, since some
        # of these Items end up in an answers file, it is possible for
        # a user to see the answer and decide to change it.  So, we need
        # to be sure to log any errors related to normally hidden (silent)
        # Items.
        prev_silent = @silent
        @silent = false
        if prev_silent
          # This is the only way to get validation errors that may be
          # logged.  Currently, PasswordItems are the only Items to log
          # validation error messages.  Since these messages are very
          # informative, we do not want to lose them.
          validate(@value)
        end
        if !allow_queries and !force_defaults
          err_msg = "FATAL: '#{@value}' is not a valid answer for '#{@key}'"
          raise Simp::Cli::Config::ValidationError.new(err_msg)
        else
          # try to fix the problem interactively or with default values, but
          # don't allow replacement values to be autogenerated, as that hides
          # the (user-created) problem
          warn(
            'WARNING: ', [:YELLOW, :BOLD],
            "The invalid value '#{@value}' for '#{@key}' will be **IGNORED**", [:YELLOW]
          )
          @value = nil
          @skip_query = false
          determine_value_without_override(allow_queries, force_defaults)
        end
      end
    end

    # query user for a value of an item
    def query
      print_banner
      @value = query_ask
    end


    # prompt to use for query
    def query_prompt
      @key
    end

    # ask an interactive question
    def query_ask
      # NOTE: The trailing space at the end of the ask() parameter
      # obliquely instructs HighLine to keep the prompt on the same
      # line as the question.  If the String did not end with a space
      # or tab, HighLine would move the input prompt to the next line
      # (which, for our purposes, looks confusing).

# FIXME:  When the more-intelligible, string color methods are
# used here instead of the ERB template, the unit tests that examine
# HighLine output fail because of missing <CR>s that are not in the
# output StringIO, even though they appear in the console output, when
# run manually.
#      value = ask( "#{query_prompt.white.bold}: ",
      value = ask( "<%= color('#{query_prompt}', WHITE, BOLD) %>: ",
                  highline_question_type ) do |q|
        q.default = default_value unless default_value.to_s.empty?

        # validate input via the validate() method
        q.validate = lambda{ |x| validate( x )}

        # do this before constructing reply to invalid response, to allow
        # any specializations to q parameters to be made (e.g., q.default)
        query_extras q

        # if the answer is not valid, construct a reply:
        q.responses[:not_valid] =  'Invalid answer!'.red + "\n"
        err_msg = not_valid_message || description
        q.responses[:not_valid] += "#{err_msg}".red
        q.responses[:ask_on_error] = :question
        q
      end
      value
    end



    def query_extras( q ); q; end


    # returns true if x is a valid value
    # Derived Items must override this method.
    def validate( _x )
      #TODO: cover common type-based validations?
      #TODO: Offer validation objects?
      raise InternalError.new( "#{self.class}.validate() not implemented!" )
    end


    def next_items
      @next_items_tree.fetch( @value, [] )
    end


    # optional message to show users when invalid input is entered
    def not_valid_message; nil; end


    # A helper method that highline can use to cast String answers to the ask
    # in query().  nil means don't cast, Date casts into a date, etc.
    # A lambda can be used for sanitization.
    #
    # Derived Items are very likely to override this method.
    def highline_question_type; nil; end

    # --------------------------------------------------------------------------
    # miscellaneous methods
    # --------------------------------------------------------------------------

    def status_color
      case (@applied_status)
      when :succeeded
        color = :GREEN
      when :unattempted, :skipped, :unnecessary
        color = :MAGENTA
      when :deferred  # operator intervention recommended
        color = :YELLOW
      when :failed
        color = :RED
      else
        color = :RED
      end
      color
    end

    # Execute a command in a child process, log failure and return
    # whether command succeeded.
    # When ignore_failure is true and command fails, does not log
    # failure and returns true
    def run_command(command, ignore_failure = false)
      debug( "Executing: #{command}" )
      # We noticed inconsistent behavior when spawning commands
      # with pipes, particularly a pipe to 'xargs'. Rejecting pipes
      # for now, but we may need to re-evaluate in the future.
      raise InvalidSpawnError.new(command) if command.include? '|'
      out_pipe_r, out_pipe_w = IO.pipe
      err_pipe_r, err_pipe_w = IO.pipe
      pid = spawn(command, :out => out_pipe_w, :err => err_pipe_w)
      out_pipe_w.close
      err_pipe_w.close

      Process.wait(pid)
      exitstatus = $?.nil? ? nil : $?.exitstatus
      stdout = out_pipe_r.read
      out_pipe_r.close
      stderr = err_pipe_r.read
      err_pipe_r.close

      return {:status => true, :stdout => stdout, :stderr => stderr} if ignore_failure

      if exitstatus == 0
        return {:status => true, :stdout => stdout, :stderr => stderr}
      else
        error( "\n[#{command}] failed with exit status #{exitstatus}:", [:RED] )
        stderr.split("\n").each do |line|
          error( ' '*2 + line, [:RED] )
        end
        return {:status => false, :stdout => stdout, :stderr => stderr}
      end
    end

    def execute(command, ignore_failure = false)
      return run_command(command, ignore_failure)[:status]
    end

    # Display an ASCII, spinning progress spinner for the action in a block
    # and return the result of that block
    # Example,
    #    result = show_wait_spinner {
    #      execute('createrepo -q -p --update .')
    #    }
    #
    # Lifted from
    # http://stackoverflow.com/questions/10262235/printing-an-ascii-spinning-cursor-in-the-console
    #
    def show_wait_spinner(frames_per_second=5)
      chars = %w[| / - \\]
      delay = 1.0/frames_per_second
      iter = 0
      spinner = Thread.new do
        while iter do  # Keep spinning until told otherwise
          print chars[(iter+=1) % chars.length]
          sleep delay
          print "\b"
        end
      end
      yield.tap {      # After yielding to the block, save the return value
        iter = false   # Tell the thread to exit, cleaning up after itself…
        spinner.join   # …and wait for it to do so.
      }                # Use the block's return value as the method's
    end

    # Retrieve the Item with the specified key from @config_items Hash
    # Raises MissingItemError if Item does not exist in @config_items
    def get_item(key)
      verify_item_present(key)
      @config_items.fetch(key)
    end

    # Verify Item with the specified key exists in @config_items Hash
    # Raises MissingItemError if Item does not exist in @config_items
    def verify_item_present(key)
      unless @config_items.key?(key)
        raise MissingItemError.new(key, self.class)
      end
    end

    # logging helper methods
    def debug(*args)
      logger.debug(*args) unless @silent
    end

    def info(*args)
      logger.info(*args) unless @silent
    end

    def warn(*args)
      logger.warn(*args) unless @silent
    end

    def error(*args)
      logger.error(*args) unless @silent
    end

    def fatal(*args)
      logger.fatal(*args) unless @silent
    end

    # pause log output to allow message of
    # message_level to be viewed on the console
    def pause(message_level, pause_seconds = PAUSE_SECONDS)
      return if @silent
      logger.pause(message_level, pause_seconds)
    end
  end

end
