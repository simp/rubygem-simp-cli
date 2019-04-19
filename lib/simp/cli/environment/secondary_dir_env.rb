require 'simp/cli/environment/env'

# Environment helper namespace
module Simp::Cli::Environment
  # Manages a "Secondary" SIMP directory environment
  # @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/760840207/Environments
  class SecondaryDirEnv < Env
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
            - [ ] C1.2 copy rsync files to ${ENVIRONMENT}/rsync/
            - [ ] C2.1 copy rsync files to ${ENVIRONMENT}/rsync/
               - [ ] this should include any logic needed to ensure a basic DNS environment
            - [ ] A5.2 ensure a `cacertkey` exists for FakeCA
               - Should this also be in fix()?

      TODO
    end

    # Fix consistency of environment
    #   @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/edit/757497857#simp_cli_environment_changes
    def fix
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
          - [ ] A2.2 apply SELinux fixfiles restore to the ${ENVIRONMENT}/ + subdirectories
            - [ ] A2.3 apply the correct SELinux contexts on demand
          - [ ] A3.2 apply Puppet user settings & groups to $ENVIRONMENT/site_files/
          - [ ] C3.2 ensure correct FACLS

      TODO
    end
  end
end
