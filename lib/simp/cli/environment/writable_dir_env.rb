require 'simp/cli/environment/env'

# Environment helper namespace
module Simp::Cli::Environment
  # Manages a "Writable" SIMP directory environment
  # @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/760840207/Environments
  class WritableDirEnv < Env
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
          - [ ] A1.2 create directory from skeleton

      TODO
    end

    # Fix consistency of environment
    #   @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/edit/757497857#simp_cli_environment_changes
    def fix
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
          - [ ] A2.3 applies Puppet user settings & groups to
            - [ ] /opt/puppetlabs/server/data/puppetserver/simp/environments/$ENVIRONMENT/
          - [ ] B3.2 ensure the correct puppet permissions at /opt/puppetlabs/

      TODO
    end
  end
end
