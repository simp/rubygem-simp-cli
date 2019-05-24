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
    end

    # If selinux is enabled, relabel the filesystem.
    # @param [Array<String>] paths   Absolute paths to apply SELinux permission
    def selinux_fix_file_contexts(paths = [])
      if Facter.value(:selinux) && !Facter.value(:selinux_current_mode).nil? &&
         (Facter.value(:selinux_current_mode) != 'disabled')
        # IDEA: test restorecon dry run to query if the policy matches what we expect it do be
        paths.each do |path|
          say("Restoring SELinux contexts under '#{path}' (this may take a while...)".cyan)
          system("restorecon -R -F -p #{path} 2>&1")
        end
      else
        say("SELinux is disabled; skipping context fixfiles for '#{path}'".yellow)
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

    # Use rsync for copy files
    # @param [String] src_dir
    # @param [String] dest_dir
    # @param [Boolean] group  apply Puppet group permissions when not falsey
    #   and user is root
    def copy_skeleton_files(src_dir, dest_dir, group=nil)
      rsync = Facter::Core::Execution.which('rsync')
      fail("Error: Could not find 'rsync' command!") unless rsync

      cmd = "#{rsync} -a '#{src_dir}'/ '#{dest_dir}'/ 2>&1"
      if ENV.fetch('USER') == 'root' && group
        cmd = %Q[sg - #{group} -c '#{rsync} -a --no-g "#{src_dir}/" "#{dest_dir}/" 2>&1']
      end

      say "Copying '#{src_dir}' files into '#{dest_dir}'".cyan
      say "    #{cmd}".gray
      output = %x(#{cmd})
      return if $CHILD_STATUS.success?
      fail(
        "ERROR: Copy of '#{src_dir}' into '#{dest_dir}',\n" \
        "  using `#{cmd}` \n" \
        "  failed with the following error:\n\n" \
        "    #{output.gsub("\n", "\n    ")}"
      )
    end
  end
end
