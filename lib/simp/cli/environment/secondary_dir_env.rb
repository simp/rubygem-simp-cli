require 'simp/cli/environment/env'

# Environment helper namespace
module Simp::Cli::Environment
  class DirEnv < Env
    def initialize(name, base_environments_path, opts)
      super(name, opts)
      @base_environments_path = base_environments_path
      @directory_path = File.join(@base_environments_path, name)
      @skeleton_path  = '' # FIXME: set skeleton path
    end


    def exists?
      File.exists? @directory_path
    end

    # If selinux is enabled, relabel the filesystem.
    def fix_file_contexts(dirs=[])
      if Facter.value(:selinux) && !Facter.value(:selinux_current_mode).nil? &&
          (Facter.value(:selinux_current_mode) != 'disabled')
        info('Relabeling filesystem for selinux (this may take a while...)', 'cyan')
        # This is silly, but there does not seem to be a way to get fixfiles
        # to shut up without specifying a logfile.  Stdout/err still make it to
        # the our logfile.
        show_wait_spinner {
          execute("fixfiles -l /dev/null -f relabel 2>&1 >> #{@logfile.path}")
        }
      end
    end

  end

  # Manages a "Secondary" SIMP directory environment
  # @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/760840207/Environments
  class SecondaryDirEnv < DirEnv
    def initialize(name, base_environments_path, opts)
      super(name, base_environments_path, opts)
    end

    # Create a new environment
    def create
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
        - [x] if environment is already deployed (#{@directory_path}/modules/*/ exist)
           - [x] THEN FAIL WITH HELPFUL MESSAGE
        - [ ] else
          - [ ] A1.2 create directory from skeleton
            - [ ] C1.2 copy rsync files to ${ENVIRONMENT}/rsync/
            - [ ] C2.1 copy rsync files to ${ENVIRONMENT}/rsync/
               - [ ] this should include any logic needed to ensure a basic DNS environment
            - [ ] A5.2 ensure a `cacertkey` exists for FakeCA
               - Should this also be in fix()?

      TODO
      if exists?
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: Can't create secondary directory at '#{@directory_path}'\n" \
          'directory already exists!'
        )
      end
    end

    # Fix consistency of environment
    #   @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/edit/757497857#simp_cli_environment_changes
    def fix
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
          - [x] if environment is not available (#{@directory_path} exists)
             - [x] THEN FAIL WITH HELPFUL MESSAGE
          - [ ] A2.2 apply SELinux fixfiles restore to the ${ENVIRONMENT}/ + subdirectories
            - [ ] A2.3 apply the correct SELinux contexts on demand
          - [ ] A3.2 apply Puppet user settings & groups to $ENVIRONMENT/site_files/
          - [ ] C3.2 ensure correct FACLS

      TODO

      unless exists?
        fail(Simp::Cli::ProcessingError, "ERROR: secondary directory not found at '#{@directory_path}'")
      end
    end
  end
end
