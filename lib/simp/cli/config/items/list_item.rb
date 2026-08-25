# frozen_string_literal: true

require_relative 'item'

module Simp::Cli::Config
  # A Item that asks for lists instead of Strings
  #
  #  note that @value  is now an Array
  class ListItem < Item
    attr_accessor :allow_empty_list

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super
      @allow_empty_list = false
    end

    def default_value_noninteractive
      value = default_value
      return [] if value.nil? && @allow_empty_list

      value
    end

    def not_valid_message
      'Invalid list.'
    end

    def instructions
      extra = 'hit enter to skip'
      extra = 'hit enter to accept default value' if default_value
      # Code actually allows comma and space delimited lists, but
      # a simpler instruction to the end user is best
      "Enter a space-delimited list (#{extra})".yellow
    end

    def query_extras(q)
      # NOTE: this is a hack to massage Array input to/from a highline query.
      # It would probably be better (but more complex) to provide native Array
      # support for highline.
      # TODO: Override #query using Highline's #gather?
      q.default  = q.default.join(' ') if q.default.is_a? Array
      q.template = "#{instructions}\n#{q.template}"
      q
    end

    def highline_question_type
      # Convert the String (delimited by comma and/or whitespace) answer into an array
      ->(str) {
        str = str.split(%r{,\s*|,?\s+}) if str.is_a? String
        str
      }
    end

    # validate the list and each item in the list
    def validate(list)
      return true if @allow_empty_list && list.nil?

      # reuse the highline lambda to sanitize input
      list = highline_question_type.call(list) unless list.is_a? Array

      return false unless list.is_a?(Array)
      return false if !@allow_empty_list && list.empty?

      list.each do |item|
        return false unless validate_item(item)
      end
      true
    end

    # validate a single list item
    def validate_item(_x)
      raise InternalError, "#{self.class}.validate_item() not implemented!"
    end
  end
end
