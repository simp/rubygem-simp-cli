require 'highline/import'
require 'puppet'
require 'yaml'
require File.expand_path( '../errors', File.dirname(__FILE__) )
require File.expand_path( '../logging', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item

    include Simp::Cli::Config::Logging

    PAUSE_SECONDS = 2 # number of seconds to pause processing to allow
                      # an important logged message to be highlighted
                      # on the screen

    attr_accessor :key, :value, :description, :data_type, :fact
    attr_accessor :start_time, :applied_status, :applied_time, :applied_detail
    attr_accessor :skip_query, :skip_apply, :skip_apply_reason, :skip_yaml, :silent
    attr_accessor :die_on_apply_fail, :allow_user_apply
    attr_accessor :config_items
    attr_accessor :next_items_tree
    attr_accessor :fail_on_missing_answer
    attr_reader   :puppet_apply_cmd

    def initialize(key = nil, description = nil)
      @key               = key           # answers file key for the config Item
      @value             = nil           # value (decided by user)
      @description       = description   # A text description of the Item
      @data_type         = :global_hiera # :internal     = used within simp config,
                                         #                 but not persisted anywhere
                                         # :cli_params   = persisted to answers YAML
                                         #                 file for use by simp config
                                         # :global_hiera = persisted to hieradata YAML
                                         #                 file for use by SIMP clients
                                         #                 and server
                                         # :server_hiera = persisted to hieradata YAML
                                         #                 file for use by SIMP server
      @fact              = nil           # Facter fact to query OS value

      @start_time        = nil           # time at which simp config started; use for backup timestamp
      @applied_status    = nil           # status of an applied change, as appropriate
      @applied_time      = nil           # time at which applied change completed
      @applied_detail    = nil           # details about the apply to be conveyed to user

      @skip_query        = false         # skip the query and use the default_value
      @skip_apply        = false         # skip the apply
      @skip_apply_reason = nil           # optional description of reason for skipping the apply
      @skip_yaml         = false         # skip yaml output

      @silent            = false         # no output to stdout/Highline/log
      @die_on_apply_fail = false         # halt simp config if apply fails
      @allow_user_apply  = false         # allow non-superuser to apply
      @fail_on_missing_answer = false    # error out if @value is not pre-populated

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


    # methods used to infer Item#value
    # --------------------------------------------------------------------------

    # value of item as read from OS (via Facter)
    def os_value
      Facter.value( @fact ) unless @fact.nil?
    end


    # value of Item as recommended by Very Clever Logic (tm)
    def recommended_value; nil; end
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


    # --------------------------------------------------------------------------
    #  Pretty stdout/stdin methods
    # --------------------------------------------------------------------------
    # print a pretty banner to describe an item
    def print_banner
      info( "=== #{@key} ===", [:CYAN, :BOLD])
      info( description, [:CYAN] )
      # inspect is a work around for Ruby 1.8.7 Array.to_s garbage
      info( "    - os value:          #{os_value.inspect}", [:CYAN] )          if os_value
      info( "    - recommended value: #{recommended_value.inspect}", [:CYAN] ) if recommended_value
      info( "    - chosen value:      #{@value.inspect}"           , [:CYAN] ) if @value
    end


    # print a pretty summary of the Item's key+value, printed to stdout
    def print_summary
      raise InternalError.new( "@key is empty for #{self.class}" ) if "#{@key}".empty?
      info( "#{@key} = ", nil, "'#{@value}", [:BOLD] )
    end


    # choose @value of Item
    def query
      log_params = query_status

      if @value.nil? && @fail_on_missing_answer
        raise "FATAL: no answer for '#{log_params[0]}#{@key}'"
      end

      if !@skip_query && @value.nil?
        print_banner
        @value = query_ask
      end

      # summarize the item's status after the query is complete
      # inspect is a work around for Ruby 1.8.7 Array.to_s garbage
      log_params += ["#{@key} = ", [], "#{@value.inspect}", [:BOLD] ]
      info(*log_params)
    end


    def query_status
      extra = []
      if !@value.nil?
        extra = ['(answered)', [:CYAN, :BOLD] ]
      elsif @skip_query
        extra = ['(noninteractive)', [:CYAN, :BOLD] ]
        @value = default_value_noninteractive
      end
      extra
    end

    # prompt to use for query
    def query_prompt
      @key
    end

    # ask an interactive question (via stdout/stdin)
    def query_ask
      # NOTE: This trailing space at the end of the String obliquely instructs
      # Highline to keep the prompt on the same line as the question.  If the
      # String did not end with a space or tab, Highline would move the input
      # prompt to the next line (which, for our purposes, looks confusing)
      value = ask( "<%= color('#{query_prompt}', WHITE, BOLD) %>: ",
                  highline_question_type ) do |q|
        q.default = default_value unless default_value.to_s.empty?

        # validate input via the validate() method
        q.validate = lambda{ |x| validate( x )}

        # do this before constructing reply to invalid response, to allow
        # any specializations to q parameters to be made (e.g., q.default)
        query_extras q

        # if the answer is not valid, construct a reply:
        q.responses[:not_valid] =  "<%= color( %q{Invalid answer!}, RED ) %>\n"
        q.responses[:not_valid] += "<%= color( %q{#{ (not_valid_message || description) }}, RED) %>\n"
        q.responses[:not_valid] += "#{q.question}  |#{q.default}|"
        q
      end
      value
    end

    # returns the default answer to Item#query
    def default_value
      @value || recommended_value
    end

    # returns the default answer to Item for noninteractive operations
    def default_value_noninteractive
      default_value
    end


    def query_extras( q ); q; end


    # returns true if x is a valid value
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
    # Descendants of Item are very likely to override this method.
    def highline_question_type; nil; end

    def safe_apply; nil; end
    def apply; nil; end

    # summary of outcome of apply
    def apply_summary; nil; end

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
    def execute(command, ignore_failure = false)
      debug( "Executing: #{command}" )
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

      return true if ignore_failure
      
      if exitstatus == 0
        return true
      else
        error( "\n[#{command}] failed with exit status #{exitstatus}:", [:RED] )
        stderr.split("\n").each do |line|
          error( ' '*2 + line, [:RED] )
        end
        return false
      end
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
