# Puppetfile helper namespace
module Simp::Cli::Environment
  # Abstract environment class
  class Env
    def initialize( name, opts )
      @name = name
      # TODO
    end

    # Create a new environment
    def create(); raise NotImplementedError; end

    # Update environment
    def update(); raise NotImplementedError; end

    # Remove environment
    def remove(); raise NotImplementedError; end

    # Validate consistency of environment
    def validate(); raise NotImplementedError; end

    # Fix consistency of environment
    def fix(); raise NotImplementedError; end

  end
end

