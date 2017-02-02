require File.expand_path( 'items', File.dirname(__FILE__) )
require File.expand_path( 'logging', File.dirname(__FILE__) )

# Builds a SIMP configuration profile based on an Array of Config::Items
#
# The configuration profile is built on a Questionnaire, which is interactive
# by default, but can be automated.
#
class Simp::Cli::Config::Questionnaire

  include Simp::Cli::Config::Logging

  INTERACTIVE           = 0
  NONINTERACTIVE        = 1
  REALLY_NONINTERACTIVE = 2

  def initialize( options = {} )
    @options = {
     :noninteractive          => INTERACTIVE,
     :verbose                 => 0
    }.merge( options )
  end


  # processes an Array of Config::Items and returns a hash of Config::Item
  # answers
  def process( item_queue=[], answers={} )
    if item = item_queue.shift
      item.config_items = answers
      process_item item

      # add (or replace) this item's answer to the answers list
      answers[ item.key ] = item

      # add any next_items to the queue
      item_queue = item.next_items + item_queue

      process item_queue, answers
    end

    answers
  end


  # process a Config::Item
  #
  # simp config can run in the following modes:
  #   - interactive (prompt each item)
  #   - mostly non-interactive (-f/-A; prompt items that can't be inferred or pulled from cli args)
  #   - never prompt (-a; optionally use cli args for non-inferrable items);
  #   - never prompt (-ff; relies on cli args for non-inferrable items))
  def process_item item
    item.skip_query = true if @options[ :noninteractive ] >= NONINTERACTIVE
    if @options.fetch( :fail_on_missing_answers, false )
      item.fail_on_missing_answer = true
    end

    if @options[ :noninteractive ] == INTERACTIVE
      item.query
    else
      value = item.default_value_noninteractive

      if item.validate( value )
        item.value = value
        item.print_summary if @options.fetch( :verbose ) >= 0
      else
        # present an interactive prompt for invalid answers unless '-ff'
        if @options.fetch( :noninteractive ) >= REALLY_NONINTERACTIVE
          raise "FATAL: '#{item.value}' is an invalid answer for '#{item.key}'"
        else
          # alert user that the value is wrong
          print_invalid_item_error item
          item.skip_query = false
          value = item.query
        end
      end
    end
    item.safe_apply
  end

  def print_invalid_item_error item
    error =  "ERROR: '#{item.value}' is not a valid value for #{item.key}"
    error += "\n#{item.not_valid_message}" if item.not_valid_message
    logger.error(error, [:RED])
  end
end
