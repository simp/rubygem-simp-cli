require 'simp/cli/environment/env'

# Environment helper namespace
module Simp::Cli::Environment
  # Abstract environment class
  class PuppetDirEnv < Env
    def initialize(name, base_environments_path, opts)
      super(name, opts)
      @base_environments_path = base_environments_path
      @directory_path = File.join(@base_environments_path, name)
    end

    # Create a new environment
    def create
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
        - [ ] if environment is already deployed (#{@directory_path}/modules/*/ exist)
           - [ ] THEN FAIL WITH HELPFUL MESSAGE
        - [ ] else
          - [ ] create directory from skeleton
            - TODO: should we ship w/a basic skeleton source and optionally
              reference one from filesystem?
        - [ ] (option-driven) generate Puppetfile
        - [ ] (option-driven) deploy modules (r10k puppetfile install)

      TODO
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
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
          - [ ] A2.3 applies Puppet user settings & groups to
            - [ ] $codedir/environments/$ENVIRONMENT/

      TODO
    end
  end
end
