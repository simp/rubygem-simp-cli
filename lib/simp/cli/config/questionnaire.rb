require File.expand_path( 'items', __dir__ )

# Builds a SIMP configuration profile based on an Array of Config::Items
#
# The configuration profile is built on a Questionnaire, which is interactive
# by default, but can be automated.
#
class Simp::Cli::Config::Questionnaire

  def initialize( options = {} )
    @options = {
     :force_defaults => false,
     :allow_queries  => true
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
  def process_item item
    item.determine_value(@options[:allow_queries], @options[:force_defaults])
    item.safe_apply if item.respond_to?(:safe_apply)
  end

end
