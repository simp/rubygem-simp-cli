require 'simp/cli/logging'
require_relative 'items'

# Builds a SIMP configuration profile based on an Array of Config::Items
#
# The configuration profile is built on a Questionnaire, which is interactive
# by default, but can be automated.
#
class Simp::Cli::Config::Questionnaire

  include Simp::Cli::Logging

  def initialize( options = {} )
    @options = {
     :force_defaults => false,
     :allow_queries  => true,
     :user_overrides => false
    }.merge( options )
  end


  # processes an Array of Config::Items and returns a hash of Config::Item
  # answers in which the key is the Item's key and the value is the Item
  # itself
  def process( item_queue=[], answers={} )
    # gather all input, execute immediate actions, and queue up all other actions
    deferred_queue = []
    answers = process_pass1( item_queue, answers, deferred_queue )

    # execute deferred actions
    process_pass2(deferred_queue, answers)
    answers
  end

  def process_pass1( item_queue, answers, deferred_queue )
    if item = item_queue.shift
      item.config_items = answers
      deferred_item = process_item(item)
      if deferred_item
        deferred_queue << deferred_item
      else
        # add (or replace) this item's answer to the answers list
        answers[ item.key ] = item
      end

      # add any next_items to the queue
      item_queue = item.next_items + item_queue

      process_pass1(item_queue, answers, deferred_queue)
    end

    answers
  end

  def process_pass2(deferred_queue, answers)
    logger.notice( "\n#{'='*80}\n" )
    if @options[:allow_queries] && !(
        @options[:dry_run] || @options[:user_overrides] || @options[:force_defaults]
    )
      # space at end of question tells HighLine to remain on the prompt line
      # when gathering user input
      logger.notice("Questionnaire is now finished.\n".green)
      logger.notice( 'Time to apply the remaining pre-bootstrap configuration.')
      question = 'Ready to apply? (no = exit with session save):'.bold + ' '
      unless agree( question ) { |q| q.default = 'yes' }
        msg = "Exiting: User terminated processing prior to final pre-bootstrap config apply.\n"
        msg += "   >> You can apply the remaining config the next time you run 'simp config'. <<\n"
        msg += "   >>>>          Enter 'yes' when asked about resuming the session          <<<<"
        raise Simp::Cli::ProcessingError.new(msg)
      end
    end

    logger.notice("\nApplying remaining pre-bootstrap configuration\n".green)
    # Execute categories of actions, retaining their relative order.
    # This provides a more coherent set of actions, but ASSUMES, no cross-category
    # action dependencies.
    Simp::Cli::Config::ActionItem::SORTED_CATEGORIES.each do |category|
      actions = deferred_queue.select { |action| action.category == category }
      process_deferred_items(actions, answers)
    end
  end

  def process_deferred_items(items, answers)
    items.each do |item|
      item.defer_apply = false
      process_item(item)

      # add (or replace) this item's answer to the answers list
      answers[ item.key ] = item
    end
  end


  # process a Config::Item
  # returns the Item if it is an ActionItem that was deferred; otherwise
  #   returns nil
  def process_item(item)
    item.determine_value(@options[:allow_queries], @options[:force_defaults])
    if item.respond_to?(:safe_apply)
      if item.defer_apply
        return item
      else
        item.safe_apply
      end
    end
    nil
  end

end
