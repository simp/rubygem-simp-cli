require 'highline/import'
require 'puppet'
require 'yaml'
require 'simp/cli/config/errors'
require 'simp/cli/defaults'
require 'simp/cli/exec_utils'
require 'simp/cli/logging'
require 'simp/cli/utils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config

  class Item

    include Simp::Cli::Logging

    PAUSE_SECONDS = 2 # number of seconds to pause processing to allow
                      # an important logged message to be highlighted
                      # on the screen

    # This constant show a stock SIMP environment set up and documents
    # the minimal Puppet env hash required to support all Items
    DEFAULT_PUPPET_ENV_INFO = {
      :puppet_config      => {
        'autosign'   => '/etc/puppetlabs/puppet/autosign.conf',
        'config'     => '/etc/puppetlabs/puppet/puppet.conf',
        'modulepath' => [
          "/etc/puppetlabs/code/environments/#{Simp::Cli::BOOTSTRAP_PUPPET_ENV}/modules",
          "/var/simp/environments/#{Simp::Cli::BOOTSTRAP_PUPPET_ENV}/site_files",
          '/etc/puppetlabs/code/modules',
          '/opt/puppetlabs/puppet/modules'
        ].join(':')
      },
      :puppet_group       => 'puppet',
      :puppet_env         => Simp::Cli::BOOTSTRAP_PUPPET_ENV,
      :puppet_env_dir     => "/etc/puppetlabs/code/environments/#{Simp::Cli::BOOTSTRAP_PUPPET_ENV}",
      :puppet_env_datadir => "/etc/puppetlabs/code/environments/#{Simp::Cli::BOOTSTRAP_PUPPET_ENV}/data",
      :secondary_env_dir  => "/var/simp/environments/#{Simp::Cli::BOOTSTRAP_PUPPET_ENV}",
      :is_pe              => Simp::Cli::Utils.is_pe?
    }

    attr_reader   :key, :description, :data_type, :fact
    attr_reader   :puppet_env_info

    attr_accessor :value
    attr_accessor :start_time
    attr_accessor :skip_query, :skip_yaml, :silent
    attr_accessor :config_items
    attr_accessor :next_items_tree

    # Derived Item classes must set @key
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
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

      @puppet_env_info   = puppet_env_info # Hash of information about SIMP's Puppet environment

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
      if (@data_type == :none) || (@data_type == :global_class)
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

    # Warning message to add to the Item's YAML comments when this Item
    # has been automatically set by `simp config`
    def auto_warning
      ">> VALUE SET BY `simp config` AUTOMATICALLY. <<\n"
    end

    # String in yaml answer file format, with comments (if any)
    def to_yaml_s(include_auto_warning = false)
      raise InternalError.new( "@key is empty for #{self.class}" ) if "#{@key}".empty?

      x =  "=== #{@key} ===\n"
      x += "#{(description || 'FIXME: NO DESCRIPTION GIVEN')}\n"
      if include_auto_warning && @skip_query && @silent
        x += auto_warning
      end

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
      notice( "\n=== #{@key} ===", [:CYAN, :BOLD])
      notice( description, [:CYAN] )
      # inspect is a work around for Ruby 1.8.7 Array.to_s garbage
      notice( "    - os value:          #{os_value.inspect}", [:CYAN] )          if os_value
      notice( "    - recommended value: #{recommended_value.inspect}", [:CYAN] ) if recommended_value
    end


    # print a pretty summary of the Item's key+value
    def print_summary
      raise InternalError.new( "@key is empty for #{self.class}" ) if "#{@key}".empty?

      log_params = []
      log_params += [ "(#{@alt_source.to_s})", [:CYAN, :BOLD] ] unless @alt_source.nil?
      log_params += ["#{@key} = ", [], "#{@value.inspect}", [:BOLD] ]
      notice(*log_params)
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
      @value = default_value_noninteractive
      # The default value *should* not require validation. However, if it is
      # computed from other Item values and ends up being invalid (typically
      # because the other Items were different than the developers had
      # anticipated and, thus, did not have adequate validation), this
      # failure will be hidden by `simp config`, and invariably will cause
      # `simp bootstrap` to fail.
      unless validate(@value)
        # Unfortunately, there is no way for the user to fix this problem.
        # The best we can do is spew enough information for a developer to debug.
        err_msg = "Default, noninteractive value for #{@key} is invalid: '#{@value}'."
        raise InternalError.new(err_msg)
      end
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
      # obliquely instructs HighLine to remain on the prompt line when
      # gathering user input.  If the String did not end with a space
      # or tab, HighLine would move to the next line (which, for our
      # purposes, looks confusing).

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

    # Execute a command in a child process, log failure and return
    # a hash with the command status, stdout and stderr.
    #
    # +command+:  Command to be executed
    # +ignore_failure+:  Whether to ignore failures.  When true and
    #   and the command fails, does not log the failure and returns
    #   a hash with :status = true
    #
    def run_command(command, ignore_failure = false)
      return Simp::Cli::ExecUtils::run_command(command, ignore_failure, logger)
    end

    # Execute a command in a child process, log failure and return
    # whether command succeeded.
    #
    # +command+:  Command to be executed
    # +ignore_failure+:  Whether to ignore failures.  When true and
    #   the command fails, does not log the failure and returns true.
    def execute(command, ignore_failure = false)
      return Simp::Cli::ExecUtils::execute(command, ignore_failure, logger)
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
    def trace(*args)
      logger.trace(*args) unless @silent
    end

    def debug(*args)
      logger.debug(*args) unless @silent
    end

    def info(*args)
      logger.info(*args) unless @silent
    end

    def notice(*args)
      logger.notice(*args) unless @silent
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
