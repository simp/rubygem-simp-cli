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

  INTRO_TEXT = <<EOM
#{'='*80}
`simp config` will take you through preparing your infrastructure for bootstrap
based on a pre-defined SIMP scenario.  These preparations include optional
and required general system setup and required Puppet configuration. All changes
will be logged to
EOM
  CONFIG_SETTINGS_FILE = 'simp_config_settings.yaml'

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

      :use_safety_save        => true,
      :autoaccept_safety_save => false
    }

    @version         = Simp::Cli::VERSION

  end

  def help
    parse_command_line( [ '--help' ] )
  end

  def run(args)
    parse_command_line(args)
    return if @help_requested
    @options[:start_time] = Time.now

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
    # the user for the scenario, as appropriate
    answers_hash = load_pre_set_answers(args, @options)

    # Generate the 'list' of Items and pre-assign Item values using
    # answers_hash.  The Item 'list' is really a decision tree, in
    # which the answer to an individual Item can simply be a system
    # setting (e.g., hieradata setting) or can be a decision point
    # dictating that other related information Items should be gathered
    # and/or a subset of system configuration should be applied.
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
  end


  def print_summary(answers)
    apply_actions = answers.select { |key,item| item.respond_to?(:applied_time) }

    unless apply_actions.empty?
      logger.info( "\n#{'='*80}", [:BOLD] )
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
    if @options.fetch( :use_safety_save, false ) && file = @options.fetch( :answers_output_file )
      _file = File.join( File.dirname( file ), ".#{File.basename( file )}" )
      if File.file?( _file )
        lines      = File.open( _file, 'r' ).readlines
        saved_hash = read_answers_file _file
        last_item  = nil
        if saved_hash.keys.size > 0
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
          logger.warn( "You can resume these answers or delete the file.\n", [color] )

          if agree( 'Resume the session? (no = deletes file)' ){ |q| q.default = 'yes' }
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
  # 4. answers from the scenario file
  #
  # Also queries user for cli::simp::scenario, if not present and
  # queries are allowed
  #
  def load_pre_set_answers(args, options)
    # Retrieve set of answers set at command line via tag=value pairs
    cli_answers = {}
    cli_answers  = Hash[ args.map{ |x| x.split '=' } ]

    # Retrieve partial set of answers from a previous interrupted session
    interrupted_session_answers = saved_session

    # Retrieve set of answers from an input answers file
    file_answers = {}
    if options.fetch(:answers_input_file)
      file_answers = read_answers_file( options.fetch(:answers_input_file) )
    end

    # Merge what has been read in so far to see if scenario is defined yet
    answers_hash = (file_answers.merge(interrupted_session_answers)).merge(cli_answers)

    # greet user before any prompts, which may be for cli::simp::scenario
    logger.info( "\n#{INTRO_TEXT.chomp}", [:GREEN] )
    logger.info( "#{' '*15}#{options[:log_file]}")
    logger.info( '='*80 + "\n", [:GREEN] )

    # Retrieve set of answer from a scenario file, prompting for scenario
    # if needed.  (We need the scenario in order to figure out which
    # which simp scenario yaml file to read).
    if !answers_hash['cli::simp::scenario']
      item = Simp::Cli::Config::Item::CliSimpScenario.new
      if options[:force_defaults]
        answers_hash['cli::simp::scenario'] =  item.default_value_noninteractive
      elsif @options[:allow_queries]
        # NOTE:  In order to persist the 'cli::simp::scenario' key in the output answers
        # yaml file, CliSimpScenario will also be in the item decision tree.  However,
        # in that tree, it will be configured to quietly use the default value, so that
        # the user isn't prompted twice.
        item.query
        item.print_summary
        answers_hash['cli::simp::scenario'] =  item.value
      else
        err_msg = "FATAL: No valid answer found for 'cli::simp::scenario'"
        raise Simp::Cli::Config::ValidationError.new(err_msg)
      end
    end
    scenario_hiera_file = File.join(Simp::Cli::Utils.simp_env_datadir,
        'scenarios', "#{answers_hash['cli::simp::scenario']}.yaml")
    unless File.exist?(scenario_hiera_file)
      # If SIMP is installed via RPMs but not the ISO and the copy
      # hasn't been made yet, the scenario YAML file should be able
      # to be found in /usr/share/simp instead.
      alt_scenario_hiera_file = File.join('/', 'usr', 'share', 'simp',
        'environments','simp', File.basename(Simp::Cli::Utils.simp_env_datadir), 'scenarios',
        "#{answers_hash['cli::simp::scenario']}.yaml")
      scenario_hiera_file = alt_scenario_hiera_file if File.exist?(alt_scenario_hiera_file)
    end
    scenario_answers = read_answers_file( scenario_hiera_file )
    answers_hash = scenario_answers.merge(answers_hash)
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
