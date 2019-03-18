require File.expand_path( 'item', __dir__ )

module Simp::Cli::Config

  # An Item that asks for an Integer instead of a String
  # NOTE:
  # - @value is a Integer
  # - os_value() and recommended_value() must return Integers
  # - validate() will be passed either an Integer or a String value,
  #   depending upon where it is called in the code. (Highline#ask()
  #   calls it with a String containing the user's input, prior to
  #   converting it to an Integer).
  class IntegerItem < Item
    # Ensure value set externally is converted to an integer
    # before being written to YAML
    def to_yaml_s
      @value = @value.to_i
      super
    end

    # Ensure queried item is converted to an integer
    def highline_question_type
      Integer
    end
  end
end
