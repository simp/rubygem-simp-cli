require_relative 'item'

module Simp::Cli::Config

  # A Item that asks for lists instead of Strings
  #
  #  note that @value  is now an Array
  class ListItem < Item
    attr_accessor :allow_empty_list

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @allow_empty_list = false
    end

    def default_value_noninteractive
      if @value.nil? and @allow_empty_list
        return []
      else
        return default_value
      end
    end

    def not_valid_message
      "Invalid list."
    end

    def instructions
      extra = 'hit enter to skip'
      extra = "hit enter to accept default value" if default_value
      # Code actually allows comma and space delimited lists, but
      # a simpler instruction to the end user is best
      instructions = "Enter a space-delimited list (#{extra})"
      ::HighLine.color( instructions, ::HighLine.const_get('YELLOW') )
    end

    def query_extras( q )
      # NOTE: this is a hack to massage Array input to/from a highline query.
      # It would probably be better (but more complex) to provide native Array
      # support for highline.
      # TODO: Override #query using Highline's #gather?
      q.default  = q.default.join( " " ) if q.default.is_a? Array
      q.template = "#{instructions}\n#{q.template}"
      q
    end

    def highline_question_type
      # Convert the String (delimited by comma and/or whitespace) answer into an array
      lambda { |str|
        str = str.split(/,\s*|,?\s+/) if str.is_a? String
        str
      }
    end

    # validate the list and each item in the list
    def validate( list )
      # reuse the highline lambda to sanitize input
      return true  if (@allow_empty_list && list.nil?)
      list = highline_question_type.call( list ) if !list.is_a? Array
      return false if !list.is_a?(Array)
      return false if (!@allow_empty_list && list.empty? )
      list.each{ |item|
        return false if !validate_item( item )
      }
      true
    end

    # validate a single list item
    def validate_item( x )
      raise InternalError.new( "#{self.class}.validate_item() not implemented!" )
    end

    # print a pretty summary of the ListItem's key+value, printed to stdout
    def print_summary
      raise InternalError.new( "@key is empty for #{self.class}" ) if "#{@key}".empty?

      if @value.nil?
        final_value = []
      else
        final_value = @value
      end
      super
    end
  end
end
