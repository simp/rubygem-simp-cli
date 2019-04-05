require 'highline/import'
require 'yaml'
require 'fileutils'
require 'find'

require 'simp/cli/commands/command'
require 'simp/cli/config/errors'
require 'simp/cli/config/items'
require 'simp/cli/config/item_list_factory'
require 'simp/cli/logging'
require 'simp/cli/config/questionnaire'

# Handle CLI interactions for "simp config"
class Simp::Cli::Commands::Config  < Simp::Cli::Commands::Command

  include Simp::Cli::Logging

  SECTION_SEPARATOR = '='*80

  INTRO_TEXT_PART1 = <<EOM
#{SECTION_SEPARATOR}
`simp config` will take you through preparing your infrastructure for bootstrap
based on a pre-defined SIMP scenario you select.  These preparations include
optional and required general system setup and required Puppet configuration.
All changes will be logged to
EOM

  INTRO_TEXT_PART2 = <<EOM
You will be prompted to enter setup information.  Each prompt will be prefaced
by a detailed description of the information requested, along with the OS value
and/or recommended value for that item, if available.

At any time, you can exit `simp config` by entering <CTRL-C>.  By default,
if you exit early, the configuration you entered will be saved to
EOM

  INTRO_TEXT_PART3 = <<EOM
The next time you run `simp config, you will be given the option to continue
where you left off or to start all over.
#{SECTION_SEPARATOR}
EOM

  def initialize

    @default_answers_outfile = File.join(Simp::Cli::SIMP_CLI_HOME, 'simp_conf.yaml')
    @options =  {
      :verbose                => 0, # <0 = ERROR and above
                                    #  0 = INFO and above
                                    # >0 = DEBUG and above
      :allow_queries          => true,
      :force_defaults         => false, # true  = use valid defaults, preemptively
      :dry_run                => false,

      :answers_input_file     => nil,
      :answers_output_file    => File.expand_path( @default_answers_outfile ),
      :puppet_system_file     => nil,

      :use_safety_save        => true,
      :autoaccept_safety_save => false,

      :start_time             => Time.now,
      :log_file               => nil,
      :clean_session          => true,  # whether we are starting the questionnaire
                                        # from the beginning and queries are allowed
      :user_overrides         => false  # whether user has provided overrides via
                                        # an answers input file or KEY=VALUE pairs
    }

    @version         = Simp::Cli::VERSION

  end

  def help
    parse_command_line( [ '--help' ] )
  end

  def run(args)
    parse_command_line(args)
    return if @help_requested

    set_up_global_logger

    # Ensure that custom facts are available before the first pluginsync
    if Simp::Cli::Utils.puppet_info[:config]['modulepath']  # nil in spec tests with Puppet 4
      Simp::Cli::Utils.puppet_info[:config]['modulepath'].split(':').each do |dir|
        next unless File.directory?(dir)
        Find.find(dir) do |mod_path|
          fact_path = File.expand_path('lib/facter', mod_path)
          Facter.search(fact_path) if File.directory?(fact_path)
          Find.prune unless mod_path == dir
        end
      end
    end

    # Load all pre-set answers (predetermined Item values), querying
    # the user for the scenario, as appropriate.
    answers_hash = load_pre_set_answers(args, @options)

    # Generate the 'list' of Items based on the scenario selected, and
    # then pre-assign Item values using the answers_hash.
    #
    # The Item 'list' is really a decision tree to be traversed by
    # Simp::Cli::Config::Questionnaire. Each entry in this list
    # represents one of the following:
    # - an individual data Item whose value may be gathered from the
    #   user or determined automatically from defaults
    # - an individual action item that specifies system configuration
    #   to apply
    # - a complex data Item (decision point) that itself contains one
    #   or more Item lists and whose value Item determines which
    #   sub-list to use when the decision tree is traversed.
    item_list = Simp::Cli::Config::ItemListFactory.new( @options ).process( answers_hash )

    # Process item tree:
    #  - Get any remaining answers via user queries or item defaults.
    #  - Apply appropriate changes to system configuration, based on
    #    the answers obtained.
    #  - When the safety-save option is enabled, after each answer is
    #    determined, persist the accumulated subset of answers for the
    #    session.
    questionnaire = Simp::Cli::Config::Questionnaire.new( @options )
    answers = questionnaire.process( item_list, {} )

    # Summarize any actions taken
    print_summary(answers) if answers

    unless @options[:verbose] < 0
      logger.say( "\n" + "Detailed log written to #{@options[:log_file]}".bold )
    end

    # Remove the copy of session answers persisted when safety-save
    # is enabled
    remove_saved_session

  rescue Simp::Cli::Config::ApplyError, Simp::Cli::Config::ValidationError => e
    # backtrace is not useful here, so only report the error message
    raise Simp::Cli::ProcessingError.new(e.message)
  end

  def greet_user
    logger.info( "\n#{INTRO_TEXT_PART1}", [:GREEN] )
    logger.info( "#{' '*15}#{@options[:log_file]}")
    logger.info( "\n#{INTRO_TEXT_PART2}", [:GREEN] )
    logger.info( "#{' '*15}#{@options[:safety_save_file]}")
    logger.info( "\n#{INTRO_TEXT_PART3}", [:GREEN] )

    first_interactive_session = @options[:clean_session] &&
      @options[:allow_queries] && !@options[:force_defaults]

    if first_interactive_session
      # space at end of question tells HighLine to remain on the prompt line
      # when gathering user input
      question = 'Ready to start the questionnaire? (no = exit program):'.bold + ' '
      unless agree( question ) { |q| q.default = 'yes' }
        raise Simp::Cli::ProcessingError.new('Exiting: User terminated processing prior to questionnaire.')
      end
    end
  end

  def parse_command_line(args)
    @default_hiera_outfile   = File.join(
      Simp::Cli::Utils::simp_env_datadir,
     'simp_config_settings.yaml'
    )
     @options[:puppet_system_file] = File.expand_path( @default_hiera_outfile )

    @opt_parser      = OptionParser.new do |opts|
      opts_separator = ' '*4 + '-'*76
      opts.banner = "\n=== The SIMP Configuration Tool ==="
      opts.separator ''
      opts.separator 'The SIMP Configuration Tool sets up the server configuration'
      opts.separator 'required for bootstrapping the SIMP system. It performs two'
      opts.separator 'main functions:'
      opts.separator ''
      opts.separator '   (1) creation/editing of system configurations'
      opts.separator '   (2) application of system configurations.'
      opts.separator ''
      opts.separator 'By default, the SIMP Configuration Tool interactively gathers'
      opts.separator 'input from the user.  However, this input can also be read in'
      opts.separator 'from an existing, complete answers YAML file; an existing,'
      opts.separator 'partial, answers YAML file and/or command line key/value'
      opts.separator 'arguments.'
      opts.separator ''
      opts.separator 'USAGE:'
      opts.separator "  #{File.basename($0)} config [options] [KEY=VALUE] [KEY=VALUE1,,VALUE2,,VALUE3] [...]"
      opts.separator ''
      opts.separator "OPTIONS:\n"
      opts.separator opts_separator

      opts.on('-o', '--answers-output FILE',
              'The answers FILE where the created/edited',
              "system configuration used by 'simp config'",
              'will be written.  Defaults to',
              "'#{@default_answers_outfile}'") do |file|
        @options[:answers_output_file] = file
      end

      opts.on('-p', '--puppet-output FILE',
              'The Puppet system FILE where the',
              'created/edited system hieradata will be',
              'written.  Defaults to',
              "'#{@default_hiera_outfile}'") do |file|
        @options[:puppet_system_file] = file
      end

      opts.on('-a', '--apply FILE', 'Apply answers FILE (fails on missing/invalid items)') do |file|
        @options[:answers_input_file] = file
        @options[:allow_queries] = false
      end

      opts.on('-A', '--apply-with-questions FILE',
              'Apply answers FILE (prompts on missing/invalid items).') do |file|
        @options[:answers_input_file] = file
        @options[:allow_queries] = true
      end

      opts.on('-f', '--force-defaults',
              'Use valid default answers for otherwise unspecified items.') do |force_defaults|
        @options[:force_defaults] = true
      end

      opts.on('--non-interactive',
              'DEPRECATED:  This has been deprecated by --force-defaults',
              'for clarity and will be removed in a future release.') do  |x|
        @options[:force_defaults] = true
      end

      opts.on('-D', '--disable-queries',
              'Run completely non-interactively. All answers must',
              'be specified by an answers file or command line',
              'KEY=VALUE pairs.') do |disable_queries|
        @options[:allow_queries] = false
      end

      opts.on('-l', '--log-file FILE',
              'Log file.  Defaults to',
              File.join(Simp::Cli::SIMP_CLI_HOME, 'simp_config.log.<timestamp>')) do |file|
        @options[:log_file] = file
      end

      opts.separator opts_separator

      opts.on('-v', '--verbose', 'Verbose output (stacks)') do
        @options[:verbose] += 1
      end

      opts.on('-q', '--quiet', 'Quiet output') do
        @options[:verbose] = -1
      end

      opts.on('-n', '--dry-run',
              'Gather input and generate answers',
              'configuration file but do not apply',
              'system changes (e.g., NIC setup, Puppet',
              'configuration changes, SIMP scenario',
              'configuration, ...)' ) do
        @options[:dry_run] = true
      end

      opts.on('-s', '--skip-safety-save',         'Ignore any safety-save files') do
        @options[:use_safety_save] = false
      end

      opts.on('-S', '--accept-safety-save',  'Automatically apply any safety-save files') do
        @options[:autoaccept_safety_save] = true
      end

      opts.separator opts_separator

      opts.on('-h', '--help', 'Print this message') do
        puts opts
        @help_requested = true
      end
      opts.separator "\nKEY/VALUE ARGUMENTS:"
      opts.separator 'The values for any of the answers file YAML keys can be set '
      opts.separator 'via key/value command line arguments:'
      opts.separator ''
      opts.separator 'KEY=VALUE syntax specifies a mapped, scalar node. For example,'
      opts.separator "  #{File.basename($0)} config simp_options::auditd=true"
      opts.separator ''
      opts.separator 'KEY=VALUE1,,VALUE2,,VALUE3 syntax specifies a mapped sequence'
      opts.separator 'node. For example,'
      opts.separator "  #{File.basename($0)} config simp_options::dns::search=domain1,,domain2"
      opts.separator ''
    end

    @opt_parser.parse!(args)

    @options[:safety_save_file] = File.join(
      File.dirname( @options[:answers_output_file] ),
      ".#{File.basename( @options[:answers_output_file] )}" )
  end


  def print_summary(answers)
    apply_actions = answers.select { |key,item| item.respond_to?(:applied_time) }

    unless apply_actions.empty?
      logger.info( "\n#{SECTION_SEPARATOR}", [:BOLD] )
      logger.info( "\nSummary of Applied Changes", [:BOLD] )
      apply_actions.each.sort{ |a,b| a[1].applied_time <=> b[1].applied_time }.each do |pair|
        item = pair[1]
        logger.info("  #{item.apply_summary}", [item.status_color, :BOLD] )
      end
    end
  end

  # Returns the saved subset of answers from the previous, interrupted
  # run, when safety-save is enabled
  def saved_session
    result = {}
    if @options.fetch( :use_safety_save, false ) && file = @options.fetch( :safety_save_file )
      _file = @options[:safety_save_file]
      if File.file?( _file )
        lines      = File.open( _file, 'r' ).readlines
        saved_hash = read_answers_file _file
        last_item  = nil
        if saved_hash.keys.size > 0
          #TODO Figure out last non-silent value the user was asked.
          # Very confusing for the user to be asked to continue on from
          # a silent Item for which the user was never queried.
          # This requires the answers file to have state info not
          # currently persisted.
          last_item = {saved_hash.keys.last =>
                       saved_hash[ saved_hash.keys.last ]}.to_yaml.gsub( /^---/, '' ).strip
        end

        color = :YELLOW
        message = %Q{WARNING: interrupted session detected!}
        logger.warn( "*** #{message} ***\n", [color, :BOLD] )
        logger.warn( 'An automatic safety-save file from a previous session has been found at:',
          [color] )
        logger.warn("      #{_file}\n", [:BOLD] )
        if last_item
          logger.warn( 'The most recent answer from this session was:', [color] )
          logger.warn( "#{last_item.gsub( /^/, "      " )}\n", [:BOLD] )
        end

        if @options.fetch( :autoaccept_safety_save, false )
          logger.warn(
              'Automatically resuming these answers because ', [color],
              '--accept-safety-save', [color,:BOLD],
              " is active.\n", [color])
          result = saved_hash
        else
          logger.warn( "You can resume the session or discard the previous answers.\n", [color] )

          # space at end of question tells HighLine to remain on the prompt line
          # when gathering user input
          question = 'Resume the session? (no = deletes saved file):'.bold + ' '
          if agree( question ) { |q| q.default = 'yes' }
            logger.info( "\nApplying answers from '#{_file}'", [:GREEN])
            result = saved_hash
          else
            logger.debug( "\nRemoving file '#{_file}'", [:RED] )
            FileUtils.rm_f _file
          end
        end
        sleep 1
      end
    end
    result
  end


  # Removes the set of answers saved during this session when the
  # safety-save operation is enabled
  def remove_saved_session
    if file = @options.fetch( :answers_output_file )
      _file = File.join( File.dirname( file ), ".#{File.basename( file )}" )
      FileUtils.rm_f( _file, :verbose => false ) if File.file?( _file )
    end
  end


  # Read in the 'answers file' containing the answers to some/all
  # of the questions 'simp config' asks (Item values), as well as
  # values 'simp config' automatically sets
  def read_answers_file(file)
    answers_hash = {}    # Read the input file

    unless File.exist?(file)
      raise Simp::Cli::ProcessingError.new("ERROR: Could not access the file '#{file}'!")
    end

    begin
      logger.debug("Loading answers from #{file}")
      answers_hash = YAML.load(File.read(file))
      answers_hash = {} if !answers_hash.is_a?(Hash) # empty yaml file returns false

    rescue Psych::SyntaxError => e
      err_msgs = [
        "ERROR: System configuration file '#{file}' is corrupted:",
        e.message,
        'Review the file and either fix or remove it before trying again.'
      ]
      raise Simp::Cli::ProcessingError.new(err_msgs.join("\n"))
    end

    answers_hash
  end


  # Read in and merge sets of answers (predetermined Item values) to
  # result in the following priority
  # 1. answers from the command line
  # 2. answers from an interrupted session
  # 3. answers from the input answers file
  #
  # Also queries user for cli::simp::scenario, if not present and
  # queries are allowed
  #
  # returns answers hash
  def load_pre_set_answers(args, options)

    # Retrieve set of answers set at command line via tag=value pairs
    cli_answers = {}
    cli_answers  = Hash[ args.map{ |x| x.split '=' } ]
    unless cli_answers.empty?
      @options[:clean_session] = false
      @options[:user_overrides] = true
    end

    # Retrieve partial set of answers from a previous interrupted session
    interrupted_session_answers = saved_session
    @options[:clean_session] = false unless interrupted_session_answers.empty?

    # Retrieve set of answers from an input answers file
    file_answers = {}
    if options.fetch(:answers_input_file)
      file_answers = read_answers_file( options.fetch(:answers_input_file) )
      @options[:clean_session] = false
      @options[:user_overrides] = true
    end

    # Merge what has been read in
    answers_hash = (file_answers.merge(interrupted_session_answers)).merge(cli_answers)

    # Greet the user now, because in the 'if' block that follows, we may
    # be starting the questionnaire with a query for cli::simp::scenario
    greet_user

    if !answers_hash['cli::simp::scenario']
      # ItemListFactory requires this in order to build the decision tree.  However,
      # in order to persist the 'cli::simp::scenario' key in the output answers
      # YAML file, CliSimpScenario must also be in the Item decision tree.  Furthermoe,
      # to prevent the user from being prompted twice, the Item MUST be configured in
      # that tree to quietly use the default value.
      #
      # FIXME This coupling is a design flaw in tree construction. ItemListFactory
      # should handle this automatically.
      item = Simp::Cli::Config::Item::CliSimpScenario.new
      if options[:force_defaults]
        answers_hash['cli::simp::scenario'] =  item.default_value_noninteractive
      elsif options[:allow_queries]
        item.query
        item.print_summary
        answers_hash['cli::simp::scenario'] =  item.value
      else
        err_msg = "FATAL: No valid answer found for 'cli::simp::scenario'"
        raise Simp::Cli::Config::ValidationError.new(err_msg)
      end
    end

    answers_hash
  end

  def set_up_global_logger
    unless @options[:log_file]
      @options[:log_file] = File.join(Simp::Cli::SIMP_CLI_HOME, "simp_config.log.#{@options[:start_time].strftime('%Y%m%dT%H%M%S')}")
    end
    FileUtils.mkdir_p(File.dirname(@options[:log_file]))
    logger.open_logfile(@options[:log_file])

    if @options[:verbose] < 0
       console_log_level = ::Logger::ERROR
    elsif @options[:verbose] == 0
       console_log_level = ::Logger::INFO
    else
       console_log_level = ::Logger::DEBUG # log action details to screen
    end
    file_log_level = ::Logger::DEBUG       # always log action details to file
    logger.levels(console_log_level, file_log_level)
  end
end
