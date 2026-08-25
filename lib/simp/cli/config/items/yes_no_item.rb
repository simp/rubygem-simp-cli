# frozen_string_literal: true

require 'highline/import'
require 'puppet'
require_relative 'item'

module Simp::Cli::Config
  # A Item that asks for lists instead of Strings
  #
  #  note that @value is a String
  class YesNoItem < Item
    def not_valid_message
      "Enter 'yes' or 'no'"
    end

    # Transform 'yes'/'no' defaults to true/false
    def default_value_noninteractive
      highline_question_type.call default_value
    end

    def validate(v)
      return true if [TrueClass, FalseClass].include?(v.class)

      (v =~ %r{^(y(es)?|true|false|no?)$}i) ? true : false
    end

    # NOTE: Highline should transform the input to a boolean but doesn't.  Why?
    # REJECTED: Override #query_ask using Highline's #agree? *** no, can't bool
    def highline_question_type
      ->(str) do
        return str if [TrueClass, FalseClass].include?(str.class)
        return true  if %r{^(y(es)?|true)$}i.match?(str.to_s)
        return false if %r{^(n(o)?|false)$}i.match?(str.to_s)

        nil
      end
    end

    # NOTE: when used from query_ask, the highline_question_type lamba doesn't
    # always cast internal type of @value to a boolean.  As a workaround, we
    # cast it here before it is committed to the super's YAML output.
    def to_yaml_s(include_auto_warning = false)
      @value = highline_question_type.call @value
      super
    end

    def next_items
      @next_items_tree.fetch(highline_question_type.call(@value), [])
    end
  end
end
