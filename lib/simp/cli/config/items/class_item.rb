require_relative 'item'

module Simp::Cli::Config

  # A special Item that is never interactive and whose output
  # is written to a class list in a global hiera file
  class ClassItem < Item

    def initialize
      super
      @data_type   = :global_class  # carries class value instead of a parameter
      @description = "'#{@key}' class to be added"
    end

    # don't be interactive!
    def validate( x );                             true; end
    def query;                                     nil;  end
    def print_summary;                             nil;  end
    def to_yaml_s( include_auto_warning = false ); nil;  end
  end
end
