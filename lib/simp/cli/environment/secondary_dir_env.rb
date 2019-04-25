require 'simp/cli/environment/env'
require 'simp/cli/logging'
require 'facter'
require 'fileutils'

# Environment helper namespace
module Simp::Cli::Environment
  class DirEnv < Env
    include Simp::Cli::Logging
    include Simp::Cli::Utils

    def initialize(name, base_environments_path, opts)
      super(name, opts)
      @base_environments_path = base_environments_path
      @directory_path = File.join(@base_environments_path, name)
      @skeleton_path  = '' # FIXME: set skeleton path
    end

    # @return [Boolean] true if the DirEnv exists
    def exists?
      File.exist? @directory_path
    end

    # If selinux is enabled, relabel the filesystem.
    # TODO: implement and test
    def selinux_fix_file_contexts(paths=[])
      if Facter.value(:selinux) && !Facter.value(:selinux_current_mode).nil? &&
          (Facter.value(:selinux_current_mode) != 'disabled')
        # This is silly, but there does not seem to be a way to get fixfiles
        # to shut up without specifying a logfile.  Stdout/err still make it to
        # the our logfile.
        Simp::Cli::Utils.show_wait_spinner {
          execute("load_policy")
          paths.each do |path|
            info("Relabeling '#{path}' for selinux (this may take a while...)", 'cyan')
            execute("fixfiles -F restore -l /dev/null -f relabel 2>&1 >> #{@logfile.path}")
          end
        }
      else
        info("SELinux is disabled; skipping context fixfiles for '#{path}'", 'yellow')
      end
    end

    # Apply Puppet permissions to a path and its contents
    # @param [String] path   path to apply permissions
    # @param [Boolean] user  apply Puppet user permissions when `true`
    # @param [Boolean] group  apply Puppet group permissions when `true`
    def apply_puppet_permissions(path, user=false, group=true )
      summary = [(user ? 'user' : nil), group ? 'group' : nil ].compact.join(" + ")
      logger.info "Applying Puppet permissions (#{summary}) under '#{path}"
      pup_user  = user ? puppet_info[:config]['user'] : nil
      pup_group = group ? puppet_info[:puppet_group] : nil
      FileUtils.chown_R(pup_user, pup_group, path)
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
          "ERROR: Directory already exists at '#{@directory_path}'\n"
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
          - [x] A2.2 apply SELinux fixfiles restore to the ${ENVIRONMENT}/ + subdirectories
            - [x] A2.3 apply the correct SELinux contexts on demand
          - [x] A3.2 apply Puppet group ownership to $ENVIRONMENT/site_files/
          - [ ] C3.2 ensure correct FACLS

      TODO

      unless exists?
        fail(Simp::Cli::ProcessingError, "ERROR: secondary directory not found at '#{@directory_path}'")
      end

      # apply SELinux fixfiles restore to the ${ENVIRONMENT}/ + subdirectories
      #
      #   previous impl: https://github.com/simp/simp-environment-skeleton/blob/6.3.0/build/simp-environment.spec#L185-L190
      #
      selinux_fix_file_contexts([@directory_path])

      # apply Puppet group ownership to $ENVIRONMENT/site_files/
      #
      #   previous impl: https://github.com/simp/simp-environment-skeleton/blob/6.3.0/build/simp-environment.spec#L181
      #
      apply_puppet_permissions(File.join(@directory_path, 'site_files'), false, true)
    end
  end
end
