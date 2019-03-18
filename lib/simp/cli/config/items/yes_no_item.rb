require 'highline/import'
require 'puppet'
require 'yaml'
require File.expand_path( 'item', __dir__ )

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

    def validate( v )
      return true if (v.class == TrueClass || v.class == FalseClass)
      ( v =~ /^(y(es)?|true|false|no?)$/i ) ? true : false
    end

    # NOTE: Highline should transform the input to a boolean but doesn't.  Why?
    # REJECTED: Override #query_ask using Highline's #agree? *** no, can't bool
    def highline_question_type
      lambda do |str|
        return true  if ( str =~ /^(y(es)?|true)$/i ? true : false || str.class == TrueClass  )
        return false if ( str =~ /^(n(o)?|false)$/i ? true : false || str.class == FalseClass )
        nil
      end
    end

    # NOTE: when used from query_ask, the highline_question_type lamba doesn't
    # always cast internal type of @value to a boolean.  As a workaround, we
    # cast it here before it is committed to the super's YAML output.
    def to_yaml_s
      @value = highline_question_type.call @value
      super
    end

    def next_items
      @next_items_tree.fetch( highline_question_type.call( @value ), [] )
    end
  end
end
