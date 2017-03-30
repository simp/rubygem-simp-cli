require File.expand_path( 'items', File.dirname(__FILE__) )
require File.expand_path( 'logging', File.dirname(__FILE__) )
require File.expand_path( 'items_yaml_generator', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config; end

# Builds an Array of Config::Items
class Simp::Cli::Config::ItemListFactory

  include Simp::Cli::Config::Logging

  def initialize( options )
    @options = {
      :verbose            => 0,
      :puppet_system_file => '/tmp/out.yaml',
    }.merge( options )

    # A hash to look up Config::Item values set from other sources (files, cli).
    # for each Hash element:
    # - the key will be the the Config::Item#key
    # - the value will be the @options#value
    @answers_hash = {}
  end


  def process( answers_hash={}, items_yaml = nil )
    @answers_hash = answers_hash

    # Require the config items
    rb_files = File.expand_path( '../config/item/*.rb', File.dirname(__FILE__))
    Dir.glob( rb_files ).sort_by(&:to_s).each { |file| require file }

    if items_yaml.nil?
      scenario = @answers_hash.fetch('cli::simp::scenario')
      items_yaml = Simp::Cli::Config::ItemsYamlGenerator.new(scenario).generate_yaml
    end

    begin
      items = YAML.load items_yaml
    rescue Psych::SyntaxError => e
      $stderr.puts "Invalid Items list YAML: #{e.message}"
      $stderr.puts '>'*80
      $stderr.puts items_yaml
      $stderr.puts '<'*80
      raise 'Internal error:  invalid Items list YAML'
    end

    # add file writers needed by all scenarios
    items <<  "HieradataYAMLFileWriter FILE=#{ @options.fetch( :puppet_system_file, '/dev/null') }"

    # Note: This is this file writer is the ONLY action that can be run as non-root user,
    #  as all it does is create a file that is not within the Puppet environment.
    items << "AnswersYAMLFileWriter   FILE=#{ @options.fetch( :answers_output_file, '/dev/null') } USERAPPLY DRYRUNAPPLY"

    item_queue = build_item_queue( [], items )
    item_queue
  end


  def assign_value_from_hash( hash, item )
    value = hash.fetch( item.key, nil )
    if !value.nil?
      # workaround to allow cli/env var arrays
      value = value.split(',,') if item.is_a?(Simp::Cli::Config::ListItem) && !value.is_a?(Array)
      if ! item.validate value
        print_warning "'#{value}' is not an acceptable answer for '#{item.key}' (skipping)."
      else
        item.value = value
      end
    end
    item
  end


  # returns an instance of an Config::Item based on a String of its class name
  def create_item item_string
    # create item instance
    parts = item_string.split( /\s+/ )
    name  = parts.shift
    item  = Simp::Cli::Config::Item.const_get(name).new

    # set item options
    #   ...based on YAML keywords
    dry_run_apply = false
    while !parts.empty?
      part = parts.shift
      if part =~ /^#/
        parts = []
        next
      end
      item.silent           = true if part == 'SILENT'
      item.skip_apply       = true if part == 'NOAPPLY'
      item.skip_query       = true if part == 'SKIPQUERY'
      item.skip_yaml        = true if part == 'NOYAML'
      item.allow_user_apply = true if part == 'USERAPPLY'
      item.generate_option  = :generate_no_query if part == 'GENERATENOQUERY'
      item.generate_option  = :never_generate    if part == 'NEVERGENERATE'
      dry_run_apply         = true if part == 'DRYRUNAPPLY'
      if part =~ /^FILE=(.+)/
        item.file = $1
      end

    end
    #  ...based on cli options
    if (@options.fetch( :dry_run, false ) and !dry_run_apply)
      item.skip_apply = true
      item.skip_apply_reason = '[**dry run**]'
    end
    item.start_time = @options.fetch( :start_time, Time.now )

    # (try to) assign item values from various sources
    item = assign_value_from_hash( @answers_hash, item )
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
    if file =  @options.fetch( :answers_output_file, nil)
      FileUtils.mkdir_p File.dirname( file ), :verbose => false
      writer = Simp::Cli::Config::Item::AnswersYAMLFileWriter.new
      file   = File.join( File.dirname( file ), ".#{File.basename( file )}" )
      writer.file             = file
      writer.allow_user_apply = true
      writer.silent           = true  if @options.fetch(:verbose, 0) < 2
      writer.start_time       = @options.fetch( :start_time, Time.now )
      # don't sort the output so we figure out the last item answered
      writer.sort_output      = false
      writer
    end
  end

  def print_warning error
    logger.warn( "WARNING: ", [:YELLOW, :BOLD], error, [:YELLOW])
  end
end
