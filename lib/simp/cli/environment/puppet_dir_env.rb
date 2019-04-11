require 'simp/cli/environment/env'

# Puppetfile helper namespace
module Simp::Cli::Environment
  # Abstract environment class
  class PuppetDirEnv < Env
    def initialize(name, opts)
      super(name, opts)
      @base_environments_path = opts[:environmentpath] || fail(ArgumentError, 'ERROR: no :environmentpath in opts')
      @directory_path = File.join(@base_environments_path, name)
    end

    # Create a new environment
    def create
      puts <<-TODO.gsub(%r{^ {6}}, '')
        IMPLEMENT LOGIC:

        - [ ] if environment is already deployed (#{@directory_path}/modules/*/ exist)
           - [ ] THEN FAIL WITH HELPFUL MESSAGE
        - [ ] else
          - [ ] create directory from skeleton
            - TODO: should we ship w/a basic skeleton source and optionally
              reference one from filesystem?
        - [ ] (option-driven) generate Puppetfile
        - [ ] (option-driven) deploy modules (r10k puppetfile install)

      TODO
      fail NotImplementedError
    end

    # Update environment
    def update
      fail NotImplementedError
    end

    # Remove environment
    def remove
      fail NotImplementedError
    end

    # Validate consistency of environment
    def validate
      fail NotImplementedError
    end

    # Fix consistency of environment
    def fix
      fail NotImplementedError
    end
  end
end
