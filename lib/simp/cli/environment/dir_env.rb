
# frozen_string_literal: true

require 'simp/cli/environment/env'
require 'simp/cli/logging'
require 'simp/cli/utils'
require 'facter'
require 'fileutils'

# Environment helper namespace
module Simp::Cli::Environment
  class DirEnv < Env
    include Simp::Cli::Logging

    attr_reader :directory_path, :base_environments_path, :skeleton_path

    def initialize(name, base_environments_path, opts)
      super(name, opts)
      @base_environments_path = base_environments_path
      @directory_path = File.join(@base_environments_path, name)
      @skeleton_path  = opts[:skeleton_path] || fail(ArgumentError, 'No :skeleton_path in opts')
    end

    # If selinux is enabled, relabel the filesystem.
    # TODO: implement and test
    def selinux_fix_file_contexts(paths = [])
      if Facter.value(:selinux) && !Facter.value(:selinux_current_mode).nil? &&
         (Facter.value(:selinux_current_mode) != 'disabled')
        # This is silly, but there does not seem to be a way to get fixfiles
        # to shut up without specifying a logfile.  Stdout/err still make it to
        # our logfile.
        Simp::Cli::Utils.show_wait_spinner do
          execute('load_policy')
          paths.each do |path|
            @logger.info("Restoring SELinux contexts under '#{path}' (this may take a while...)", 'cyan')
            execute("restorecon -R -F -p #{path} 2>&1 >> #{@logfile.path}")
          end
        end
      else
        @logger.info("SELinux is disabled; skipping context fixfiles for '#{path}'", 'yellow')
      end
    end

    # Apply Puppet permissions to a path and its contents
    # @param [String] path   path to apply permissions
    # @param [Boolean] user  apply Puppet user permissions when `true`
    # @param [Boolean] group  apply Puppet group permissions when `true`
    def apply_puppet_permissions(path, user = false, group = true)
      summary = [(user ? 'user' : nil), group ? 'group' : nil].compact.join(' + ')
      logger.info "Applying Puppet permissions (#{summary}) under '#{path}"
      pup_user  = user ? puppet_info[:config]['user'] : nil
      pup_group = group ? puppet_info[:puppet_group] : nil
      FileUtils.chown_R(pup_user, pup_group, path)
    end
  end
end
