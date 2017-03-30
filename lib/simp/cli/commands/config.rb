require 'highline/import'
require 'yaml'
require 'fileutils'
require 'find'

require File.expand_path( '../../cli', File.dirname(__FILE__) )
require File.expand_path( '../defaults', File.dirname(__FILE__) )
require File.expand_path( '../config/items', File.dirname(__FILE__) )
require File.expand_path( '../config/item_list_factory', File.dirname(__FILE__) )
require File.expand_path( '../config/logging', File.dirname(__FILE__) )
require File.expand_path( '../config/questionnaire', File.dirname(__FILE__) )

module Simp::Cli::Commands; end

# Handle CLI interactions for "simp config"
class Simp::Cli::Commands::Config  < Simp::Cli

  include Simp::Cli::Config::Logging

  DEFAULT_ANSWERS_OUTFILE = File.join(SIMP_CLI_HOME, 'simp_conf.yaml')

  DEFAULT_HIERA_OUTFILE =
    "#{::Utils.puppet_info[:simp_environment_path]}/hieradata/simp_config_settings.yaml"

  SIMP_CONFIG_DEFAULT_OPTIONS = {
    :verbose                 => 0,
    :noninteractive          => 0, # TODO: between these two, we should choose better names
    :dry_run                 => false,

    :scenario                => nil,
    :answers_input_file      => nil,
    :answers_output_file     => File.expand_path( DEFAULT_ANSWERS_OUTFILE ),
    :puppet_system_file      => File.expand_path( DEFAULT_HIERA_OUTFILE ),

    :use_safety_save         => true,
    :autoaccept_safety_save  => false,
    :fail_on_missing_answers => false   # false = prompt upon failure
  }

  INTRO_TEXT = <<EOM
#{'='*80}
`simp config` will take you through preparing your infrastructure for bootstrap
based on a pre-defined SIMP scenario.  These preparations include optional
and required general system setup and required Puppet configuration. All changes
will be logged to
EOM

  @version         = Simp::Cli::VERSION
  @options         = SIMP_CONFIG_DEFAULT_OPTIONS

  @opt_parser      = OptionParser.new do |opts|
    opts_separator = ' '*4 + '-'*76
    opts.banner = "\n=== The SIMP Configuration Tool ==="
    opts.separator ""
    opts.separator "The SIMP Configuration Tool sets up the server configuration"
    opts.separator "required for bootstrapping the SIMP system. It performs two"
    opts.separator "main functions:"
    opts.separator ""
    opts.separator "   (1) creation/editing of system configurations"
    opts.separator "   (2) application of system configurations."
    opts.separator ""
    opts.separator "By default, the SIMP Configuration Tool interactively gathers"
    opts.separator "input from the user.  However, this input can also be read in"
    opts.separator "from an existing, complete answers YAML file; an existing,"
    opts.separator "partial, answers YAML file and/or command line key/value"
    opts.separator "arguments."
    opts.separator ""
    opts.separator "USAGE:"
    opts.separator "  #{File.basename($0)} config [options] [KEY=VALUE] [KEY=VALUE1,,VALUE2,,VALUE3] [...]"
    opts.separator ""
    opts.separator "OPTIONS:\n"
    opts.separator opts_separator

    opts.on("-o", "--answers-output FILE",
            "The answers FILE where the created/edited",
            "system configuration used by 'simp config'",
            "will be written.  Defaults to",
            "'#{DEFAULT_ANSWERS_OUTFILE}'") do |file|
      @options[:answers_output_file] = file
    end

    opts.on("-p", "--puppet-output FILE",
            "The Puppet system FILE where the",
            "created/edited system hieradata will be",
            "written.  Defaults to ",
            "'#{DEFAULT_HIERA_OUTFILE}'") do |file|
      @options[:puppet_system_file] = file
    end

    opts.on("-a", "--apply FILE", "Apply answers FILE (fails on missing items)") do |file|
      @options[:answers_input_file] = file
      @options[:fail_on_missing_answers] = true
    end

    opts.on("-A", "--apply-with-questions FILE",
            "Apply answers FILE (asks on missing items).") do |file|
      @options[:answers_input_file] = file
      @options[:fail_on_missing_answers] = false
    end

    opts.on("-l", "--log-file FILE",
            "Log file.  Defaults to ",
            File.join(SIMP_CLI_HOME, 'simp_config.log.<timestamp>')) do |file|
      @options[:log_file] = file
    end

    opts.separator opts_separator

    # TODO: improve nomenclature
    opts.on("-v", "--verbose", "Verbose output (stacks)") do
      @options[:verbose] += 1
    end

    opts.on("-q", "--quiet", "Quiet output") do
      @options[:verbose] = -1
    end

    opts.on("-n", "--dry-run",
            "Gather input and generate answers",
            "configuration file but do not apply",
            "system changes (e.g., NIC setup, Puppet",
            "configuration changes, SIMP scenario",
            "configuration, ...)" ) do
      @options[:dry_run] = true
    end

    opts.on("-f", "--non-interactive", "Force default answers (prompt if unknown)"
                                       ) do |file|
      # FIXME there is some logic/comments for -ff/REALLY_NONINTERACTIVE in
      #  questionnaire.rb that may be OBE.
      @options[:noninteractive] += 1
    end

    opts.on("-s", "--skip-safety-save",         "Ignore any safety-save files") do
      @options[:use_safety_save] = false
    end

    opts.on("-S", "--accept-safety-save",  "Automatically apply any safety-save files") do
      @options[:autoaccept_safety_save] = true
    end

    opts.separator opts_separator

    opts.on("-h", "--help", "Print this message") do
      puts opts
      @help_requested = true
    end
    opts.separator "\nKEY/VALUE ARGUMENTS:"
    opts.separator "The values for any of the answers file YAML keys can be set "
    opts.separator "via key/value command line arguments:"
    opts.separator ""
    opts.separator "KEY=VALUE syntax specifies a mapped, scalar node. For example,"
    opts.separator "  #{File.basename($0)} config simp_options::auditd=true"
    opts.separator ""
    opts.separator "KEY=VALUE1,,VALUE2,,VALUE3 syntax specifies a mapped sequence"
    opts.separator "node. For example,"
    opts.separator "  #{File.basename($0)} config simp_options::dns::search=domain1,,domain2"
    opts.separator ""
  end

  def self.print_summary(answers)
    apply_actions = answers.select { |key,value| value.applied_time }
    unless apply_actions.empty?
      logger.info( "\n#{'='*80}", [:BOLD] )
      logger.info( "\nSummary of Applied Changes", [:BOLD] )
      apply_actions.each.sort{ |a,b| a[1].applied_time <=> b[1].applied_time }.each do |pair|
        item = pair[1]
        logger.info("  #{item.apply_summary}", [item.status_color, :BOLD] )
      end
    end
  end

  def self.saved_session
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
        logger.warn( "An automatic safety-save file from a previous session has been found at:",
          [color] )
        logger.warn("      #{_file}\n", [:BOLD] )
        if last_item
          logger.warn( "The most recent answer from this session was:", [color] )
          logger.warn( "#{last_item.gsub( /^/, "      " )}\n", [:BOLD] )
        end

        if @options.fetch( :autoaccept_safety_save, false )
          logger.warn(
              "Automatically resuming these answers because ", [color],
              "--accept-safety-save", [color,:BOLD],
              " is active.\n", [color])
          result = saved_hash
        else
          logger.warn( "You can resume these answers or delete the file.\n", [color] )

          if agree( "Resume the session? (no = deletes file)" ){ |q| q.default = 'yes' }
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


  def self.remove_saved_session
    if file = @options.fetch( :answers_output_file )
      _file = File.join( File.dirname( file ), ".#{File.basename( file )}" )
      FileUtils.rm_f( _file, :verbose => false ) if File.file?( _file )
    end
  end


  def self.read_answers_file file
    answers_hash = {}    # Read the input file

    unless File.exist?(file)
      raise "ERROR: Could not access the file '#{file}'!"
    end

    begin
      logger.debug("Loading answers from #{file}")
      answers_hash = YAML.load(File.read(file))
      answers_hash = {} if !answers_hash.is_a?(Hash) # empty yaml file returns false

    rescue SignalException => e
      raise
    rescue Psych::SyntaxError => e
      raise "ERROR: System configuration file '#{file}' is corrupted:\n" +  e.message +
       "\nReview the file and either fix or remove it before trying again."
    end

    answers_hash
  end

  def self.run(args = [])
    super # parse @options, will raise upon parsing error
    return if @help_requested
    @options[:start_time] = Time.now

    set_up_logger

    # Ensure that custom facts are available before the first pluginsync
    if ::Utils.puppet_info[:config]['modulepath']  # nil in spec tests with Puppet 4
      ::Utils.puppet_info[:config]['modulepath'].split(':').each do |dir|
        next unless File.directory?(dir)
        Find.find(dir) do |mod_path|
          fact_path = File.expand_path('lib/facter', mod_path)
          Facter.search(fact_path) if File.directory?(fact_path)
          Find.prune unless mod_path == dir
        end
      end
    end

    # Read in and merge sets of answers (predetermined settings) to result
    # in the following priority
    # 1. answers from the command line
    # 2. answers from an interrupted session
    # 3. answers from the input answers file
    # 4. answers from the scenario file

    # Retrieve set of answers set at command line via tag=value pairs
    cli_answers = {}
    cli_answers  = Hash[ args.map{ |x| x.split '=' } ]

    # Retrieve partial set of answers from a previous interrupted session
    interrupted_session_answers = saved_session

    # Retrieve set of answers from an input answers file
    file_answers = {}
    if @options.fetch(:answers_input_file)
      file_answers = read_answers_file( @options.fetch(:answers_input_file) )
    end

    # Merge what has been read in so far to see if scenario is defined yet
    answers_hash = (file_answers.merge(interrupted_session_answers)).merge(cli_answers)

    # greet user before any prompts
    logger.info( "\n#{INTRO_TEXT.chomp}", [:GREEN] )
    logger.info( "#{' '*15}#{@options[:log_file]}")
    logger.info( '='*80 + "\n", [:GREEN] )

    # Retrieve set of answer from a scenario file, prompting for scenario if needed
    unless answers_hash['cli::simp::scenario']
      # prompt user so we can figure out which yaml file to read
      # NOTE:  In order to persist the 'cli::simp::scenario' key in the output answers
      # yaml file, CliSimpScenario will also be in the item decision tree.  However,
      # in that tree, it will be configured with the 'SKIPQUERY SILENT' options, so that
      # the user isn't prompted twice.
      item = Simp::Cli::Config::Item::CliSimpScenario.new
      item.query
      answers_hash['cli::simp::scenario'] =  item.value
    end
    scenario_hiera_file = File.join(::Utils.puppet_info[:simp_environment_path],
        'hieradata', 'scenarios', "#{answers_hash['cli::simp::scenario']}.yaml")
    unless File.exist?(scenario_hiera_file)
      # If SIMP is installed via RPMs but not the ISO and the copy
      # hasn't been made yet, the scenario YAML file should be able
      # to be found in /usr/share/simp instead.
      alt_scenario_hiera_file = File.join('/', 'usr', 'share', 'simp',
        'environments','simp', 'hieradata', 'scenarios',
        "#{answers_hash['cli::simp::scenario']}.yaml")
      scenario_hiera_file = alt_scenario_hiera_file if File.exist?(alt_scenario_hiera_file)
    end
    scenario_answers = read_answers_file( scenario_hiera_file )
    answers_hash = scenario_answers.merge(answers_hash)

    # Get the list (decision tree) of items
    #  - applies any known answers at this point
    item_list = Simp::Cli::Config::ItemListFactory.new( @options ).process( answers_hash )

    # Process item tree:
    #  - get any remaining answers from user
    #  - apply changes as needed
    questionnaire = Simp::Cli::Config::Questionnaire.new( @options )
    answers = questionnaire.process( item_list, {} )
    print_summary(answers) if answers

    logger.say( "\n<%= color(%q{Detailed log written to #{@options[:log_file]}}, BOLD) %>" )

    remove_saved_session
  end

  def self.set_up_logger
    unless @options[:log_file]
      @options[:log_file] = File.join(SIMP_CLI_HOME, "simp_config.log.#{@options[:start_time].strftime('%Y%m%dT%H%M%S')}")
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

  # Resets options to original values.
  # This ugly method is needed for unit-testing, in which multiple occurrences of
  # the self.run method are called with different options.
  # FIXME Variables set here are really class variables, not instance variables.
  def self.reset_options
    @options = Hash.new.update(SIMP_CONFIG_DEFAULT_OPTIONS)
    @help_requested = false
  end
end
