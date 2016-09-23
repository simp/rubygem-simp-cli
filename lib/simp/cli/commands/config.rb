require 'highline/import'
require 'yaml'
require 'fileutils'
require 'find'

require File.expand_path( '../../cli', File.dirname(__FILE__) )
require File.expand_path( '../config/item', File.dirname(__FILE__) )
require File.expand_path( '../config/questionnaire', File.dirname(__FILE__) )
require File.expand_path( '../config/item_list_factory', File.dirname(__FILE__) )

module Simp::Cli::Commands; end

# Handle CLI interactions for "simp config"
class Simp::Cli::Commands::Config  < Simp::Cli
  DEFAULT_OUTFILE = '~/.simp/simp_conf.yaml'
  SIMP_CONFIG_DEFAULT_OPTIONS = {
    :verbose            => 0,
    :noninteractive     => 0,
    :dry_run            => false, # TODO: between these two, we should choose better names

    :input_file         => nil,
    :output_file        => File.expand_path( DEFAULT_OUTFILE ),
    :puppet_system_file => "#{::Utils.puppet_info[:simp_environment_path]}/hieradata/simp_def.yaml",

    :use_safety_save         => true,
    :autoaccept_safety_save  => false,
    :fail_on_missing_answers => false,
  }
  INTRO_TEXT = <<EOM
`simp config` will take you through preparing your infrastructure for bootstrap.

Changes here are made to ensure that `simp bootstrap` will run and you have
the needed files and settings to bootstrap successfully.
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

    opts.on("-o", "--output FILE", "The answers FILE where the created/edited ",
                                   "system configuration will be written.  ",
                                   "  (defaults to '#{DEFAULT_OUTFILE}')") do |file|
      @options[:output_file] = file
    end

    opts.on("-i", "-a", "-e", "--apply FILE", "Apply answers FILE (fails on missing items)"
                                              ) do |file|
      @options[:input_file] = file
      @options[:fail_on_missing_answers] = true
    end

    opts.on("-I", "-A", "-E", "--apply-with-questions FILE",
                                              "Apply answers FILE (asks on missing items) ",
                                              "  Note that the edited configuration",
                                              "  will be written to the file specified in ",
                                              "   --output.") do |file|
      @options[:input_file] = file
      @options[:fail_on_missing_answers] = false
    end

    opts.separator opts_separator

    # TODO: improve nomenclature
    opts.on("-v", "--verbose", "Verbose output (stacks)") do
      @options[:verbose] += 1
    end

    opts.on("-q", "--quiet", "Quiet output (clears any verbosity)") do
      @options[:verbose] = -1
    end

    opts.on("-n", "--dry-run",         "Do not apply system changes",
                                       "  (e.g., NICs, puppet.conf, etc)" ) do
      @options[:dry_run] = true
    end

    opts.on("-f", "--non-interactive", "Force default answers (prompt if unknown)"
                                       #"  (-ff fails instead of prompting)"
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
    opts.separator "  #{File.basename($0)} config use_auditd=true"
    opts.separator ""
    opts.separator "KEY=VALUE1,,VALUE2,,VALUE3 syntax specifies a mapped sequence"
    opts.separator "node. For example,"
    opts.separator "  #{File.basename($0)} config dns::search=domain1,,domain2"
    opts.separator ""
  end

  def self.print_summary(answers)
    apply_actions = answers.select { |key,value| value.applied_time }
    unless apply_actions.empty?
      say ( "\n<%= color(%q{==========================}, BOLD) %>\n" )
      say ( "\n<%= color(%q{Summary of Applied Changes}, BOLD) %>\n" )
      apply_actions.each.sort{ |a,b| a[1].applied_time <=> b[1].applied_time }.each do |pair|
        item = pair[1]
        say "  <%= color(%q{#{item.apply_summary}}, #{item.status_color}, BOLD) %>\n" #unless item.silent
      end
    end
  end

  def self.saved_session
    result = {}
    if @options.fetch( :use_safety_save, false ) && file = @options.fetch( :output_file )
      _file = File.join( File.dirname( file ), ".#{File.basename( file )}" )
      if File.file?( _file )
        lines      = File.open( _file, 'r' ).readlines
        saved_hash = read_answers_file _file
        last_item  = nil
        if saved_hash.keys.size > 0
          last_item = {saved_hash.keys.last =>
                       saved_hash[ saved_hash.keys.last ]}.to_yaml.gsub( /^---/, '' ).strip
        end

        message = %Q{WARNING: interrupted session detected!}
        say "<%= color(%q{*** #{message} ***}, YELLOW, BOLD) %> \n\n"
        say "<%= color(%q{An automatic safety-save file from a previous session has been found at:}, YELLOW) %> \n\n"
        say "      <%= color( %q{#{_file}}, BOLD ) %>\n\n"
        if last_item
          say "<%= color(%q{The most recent answer from this session was:}, YELLOW) %> \n\n"
          say "<%= color( %q{#{last_item.gsub( /^/, "      \0" )}} ) %>\n\n"
        end

        if @options.fetch( :autoaccept_safety_save, false )
          color = 'YELLOW'
          say "<%= color(%q{Automatically resuming these answers because }, #{color}) %>" +
              "<%= color(%q{--accept-safety-save}, BOLD, #{color}) %>" +
              "<%= color(%q{ is active.}, #{color}) %>\n\n"
          result = saved_hash
        else
          say "<%= color(%q{You can resume these answers or delete the file.}, YELLOW) %>\n\n"

          if agree( "resume the session? (no = deletes file)" ){ |q| q.default = 'yes' }
            say "\n<%= color( %q{applying answers from '#{_file}'}, GREEN )%>\n"
            result = saved_hash
          else
            say "\n<%= color( %q{removing file '#{_file}'}, RED )%>\n"
            FileUtils.rm_f _file, :verbose => true
          end
        end
        sleep 1
      end
    end
    result
  end


  def self.remove_saved_session
    if file = @options.fetch( :output_file )
      _file = File.join( File.dirname( file ), ".#{File.basename( file )}" )
      FileUtils.rm_f( _file, :verbose => false ) if File.file?( _file )
    end
  end


  def self.read_answers_file file
    answers_hash = {}    # Read the input file

    unless File.exist?(file)
      raise "Could not access the file '#{file}'!"
    end

    begin
      answers_hash = YAML.load(File.read(file))
      answers_hash = {} if !answers_hash.is_a?(Hash) # empty yaml file returns false

    # If the file existed, but ingest failed, then there's a problem. Unfortunately,
    # the YAML library in Ruby has changed between Ruby 1.8.7 and Ruby 2.0.0 in a way
    # that makes it impossible to catch YAML-specific exceptions. (The underlying YAML
    # engine in Ruby 2.0.0 is way more functional, but raises exceptions that are
    # not available in Ruby 1.8.7 and whose classes are not derived from exceptions
    # in the Ruby 1.8.7 YAML parser). So, we must rescue and re-raise any other
    # unrelated exceptions may occur first, or these exceptions will be reported
    # incorrectly as configuration-file-parsing failures!
    rescue SignalException => e
      raise
    rescue Exception => e
      raise "System configuration file '#{file}' is corrupted:\n" +  e.message +
       "\nReview the file and either fix or remove it before trying again."
    end

    answers_hash
  end

  def self.run(args = [])
    super # parse @options, will raise upon parsing error
    return if @help_requested

    # Ensure that custom facts are available before the first pluginsync
    %x{puppet config print modulepath}.strip.split(':').each do |dir|
      next unless File.directory?(dir)
      Find.find(dir) do |mod_path|
        fact_path = File.expand_path('lib/facter', mod_path)
        Facter.search(fact_path) if File.directory?(fact_path)
        Find.prune unless mod_path == dir
      end
    end

    # read in answers file
    answers_hash = {}
    if file = @options.fetch( :input_file )
      answers_hash = read_answers_file( file )
    end

    # NOTE: answers from an interrupted session take precedence over input file
    answers_hash = saved_session.merge( answers_hash )

    # NOTE: answers provided from the cli take precedence over everything else
    cli_answers  = Hash[ args.map{ |x| x.split '=' } ]
    answers_hash = answers_hash.merge( cli_answers )

    # get the list of items
    #  - applies any known answers at this point
    item_list          = Simp::Cli::Config::ItemListFactory.new( @options ).process( nil, answers_hash )

    # greet user with intro message
    say ( "\n<%= color(%Q{#{INTRO_TEXT}}, GREEN) %>\n" )

    # process items:
    #  - get any remaining answers
    #  - apply changes as needed
    questionnaire      = Simp::Cli::Config::Questionnaire.new( @options )
    answers            = questionnaire.process( item_list, {} )
    print_summary(answers) if answers

    remove_saved_session
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
