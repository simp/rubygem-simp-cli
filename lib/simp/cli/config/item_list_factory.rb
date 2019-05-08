require_relative 'errors'
require_relative 'items'
require_relative '../logging'
require_relative 'items_yaml_generator'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config; end

# Builds an Array of Config::Items
class Simp::Cli::Config::ItemListFactory

  include Simp::Cli::Logging

  def initialize( options )
    @options = {
      :answers_output_file  => '/dev/null',
      :hiera_output_file    => '/dev/null',
      :puppet_env           => Simp::Cli::BOOTSTRAP_PUPPET_ENV,
      :force_defaults       => false,
      :allow_queriers       => true,
      :dry_run              => false,
      :start_time           => Time.now,
      :safety_save_file     => nil,
      :clean_session        => true,
      :verbose              => 0,
    }.merge( options )

    # A hash to look up Config::Item values set from other sources (files, cli).
    # for each Hash element:
    # - the key will be the the Config::Item#key
    # - the value will be the @options#value
    @answers_hash = {}
  end


  # Generate Item 'list'
  #
  # +answers_hash+: Hash of Item pre-set values
  # +items_yaml+: Decision tree YAML to use in lieu of building
  #   one to correspond to the 'cli::simp::scenario'
  #
  # @raise Simp::Cli::Config::ValidationError if 'cli::simp::scenario'
  #   is not available in answers_hash and querying is not allowed
  def process( answers_hash={}, items_yaml = nil )
    @answers_hash = answers_hash.dup

    if items_yaml.nil?
      query_for_scenario unless @answers_hash.key?('cli::simp::scenario')
      scenario = @answers_hash['cli::simp::scenario']
      items_yaml = Simp::Cli::Config::ItemsYamlGenerator.new(scenario).generate_yaml
    end

#FIXME automatically add CliSimpScenario to Items tree at the beginning

    begin
      items = YAML.load items_yaml
    rescue Psych::SyntaxError => e
      logger.error("Invalid Items list YAML: #{e.message}".red)
      logger.error('>'*80)
      logger.error(items_yaml)
      logger.error('<'*80)
      raise Simp::Cli::Config::InternalError.new('invalid Items list YAML')
    end

    # add file writers needed by all scenarios
    items <<  "HieradataYAMLFileWriter FILE=#{ @options[:hiera_output_file] }"

    # Note: This is this file writer is the ONLY action that can be run as non-root user,
    #  as all it does is create a file that is not within the Puppet environment.
    items << "AnswersYAMLFileWriter   FILE=#{ @options[:answers_output_file] } USERAPPLY DRYRUNAPPLY"

    item_queue = build_item_queue( [], items )
    item_queue
  end


  def assign_value_from_hash( hash, item )
    value = hash.fetch( item.key, nil )
    if !value.nil?
      # workaround to allow cli/env var arrays
      value = value.split(',,') if item.is_a?(Simp::Cli::Config::ListItem) && !value.is_a?(Array)

      # validation is deferred until the Item is processed, to allow
      # any invalid value message to appear in the appropriate context
      item.value = value
    end
    item
  end


  # returns an instance of an Config::Item based on a String of its class name
  def create_item item_string
    # create item instance
    parts = item_string.split( /\s+/ )
    name  = parts.shift
    item  = Simp::Cli::Config::Item.const_get(name).new(@options[:puppet_env_info])
    override_value = nil

    # set item options
    #   ...based on YAML keywords
    dry_run_apply = false
    while !parts.empty?
      part = parts.shift
      if part =~ /^#/
        parts = []
        next
      end
      item.silent           = true  if part == 'SILENT'
      item.skip_query       = true  if part == 'SKIPQUERY'
      item.skip_yaml        = true  if part == 'NOYAML'
      if item.respond_to?(:safe_apply)
        item.skip_apply       = true  if part == 'NOAPPLY'
        item.allow_user_apply = true  if part == 'USERAPPLY'
        item.defer_apply      = false if part == 'IMMEDIATE'
      end
      if part == 'GENERATENOQUERY'
        item.skip_query      = true
        item.generate_option = :generate_no_query
      end
      item.generate_option  = :never_generate if part == 'NEVERGENERATE'
      dry_run_apply         = true            if part == 'DRYRUNAPPLY'
      if part =~ /^FILE=(.+)/
        item.file = $1
      end
      if part =~ /^VALUE=(.+)/
        # This **ASSUMES** the Item can handle any transformations of
        # this value (e.g., 'yes' => true), even when the Item's
        # skip_query is true.
        override_value = $1
      end

    end
    #  ...based on cli options
    if ( @options[:dry_run] and
         !dry_run_apply and
         item.respond_to?(:safe_apply)
       )
      item.skip_apply = true
      item.skip_apply_reason = '[**dry run**]'
    end
    item.start_time = @options[:start_time]

    # pre-assign item value from various sources, if available
    item = assign_value_from_hash( @answers_hash, item )

    # override the pre-assigns, as needed, sigh
    item.value = override_value if override_value
    item
  end


  # recursively build an item queue
  def build_item_queue( item_queue, items )
    writer = create_safety_writer_item
    if !items.empty?
      item = items.shift
      item_queue << writer if writer

      if item.is_a? String
        item_queue << create_item( item )

      elsif item.is_a? Hash
        answers_tree = {}
        item.values.first.each{ |answer, values|
          answers_tree[ answer ] = build_item_queue( [], values )
        }
        _item = create_item( item.keys.first )
        _item.next_items_tree = answers_tree
        item_queue << _item
        # append a silent YAML writer to save progress after each item
        item_queue << writer if writer
      end

      item_queue = build_item_queue( item_queue, items )
    end

    item_queue
  end


  # create a YAML writer that will "safety save" after each answer
  def create_safety_writer_item
    if file =  @options[:safety_save_file]
      FileUtils.mkdir_p File.dirname( file ), :verbose => false
      writer = Simp::Cli::Config::Item::AnswersYAMLFileWriter.new(@options[:puppet_env_info])
      writer.file             = file
      writer.allow_user_apply = true
      writer.defer_apply      = false  # make sure we apply immediately
      writer.silent           = true  if @options[:verbose] < 2
      writer.start_time       = @options[:start_time]
      # don't sort the output so we figure out the last item answered
      writer.sort_output      = false
      writer
    end
  end

  def query_for_scenario
    item = Simp::Cli::Config::Item::CliSimpScenario.new(@options[:puppet_env_info])

    if @options[:force_defaults]
      @answers_hash['cli::simp::scenario'] = item.default_value_noninteractive
    elsif @options[:allow_queries]
      if @options[:clean_session]
        # This is the first interactive session, so ensure user is ready to
        # continue

        # space at end of question tells HighLine to remain on the prompt line
        # when gathering user input
        question = "\nReady to start the questionnaire? (no = exit program):".bold + ' '
        unless agree( question ) { |q| q.default = 'yes' }
          raise Simp::Cli::ProcessingError.new('Exiting: User terminated processing prior to questionnaire.')
        end
      end
      item.query
      item.print_summary
      @answers_hash['cli::simp::scenario'] = item.value
    else
      err_msg = "FATAL: No valid answer found for 'cli::simp::scenario'"
      raise Simp::Cli::Config::ValidationError.new(err_msg)
    end
  end
end
