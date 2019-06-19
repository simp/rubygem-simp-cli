# frozen_string_literal: true

require 'simp/cli/environment/env'
require 'simp/cli/logging'
require 'facter'
require 'fileutils'

# Environment helper namespace
module Simp::Cli::Environment
  class DirEnv < Env

    attr_reader :directory_path, :base_environments_path, :skeleton_path

    def initialize(type, name, base_environments_path, opts)
      super(type, name, opts)
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
          info("Restoring SELinux contexts under '#{path}' (this may take a while...)".cyan)
          #FIXME should we fail if this fails?
          execute("restorecon -R -F -p #{path}")
        end
      else
        info("SELinux is disabled; skipping context fixfiles for '#{paths}'".yellow)
      end
    end

    # Apply Puppet permissions to a path and its contents
    # @param [String] path   path to apply permissions
    # @param [Boolean] user  apply Puppet user permissions when `true`
    # @param [Boolean] group  apply Puppet group permissions when `true`
    # @param [Boolean] recursive  apply Puppet permissions recursively when `true`
    def apply_puppet_permissions(path, user = false, group = true, recursive = true)
      summary = [(user ? 'user' : nil), group ? 'group' : nil].compact.join(' + ')
      pup_user  = user ? puppet_info[:config]['user'] : nil
      pup_group = group ? puppet_info[:puppet_group] : nil
      if recursive
        info("Applying Puppet permissions (#{summary}) recursively under '#{path}'".cyan)
        FileUtils.chown_R(pup_user, pup_group, path)
      else
        info("Applying Puppet permissions (#{summary}) to '#{path}'".cyan)
        FileUtils.chown(pup_user, pup_group, path)
      end
    end

    # Use rsync for copy files
    # @param [String] src_dir
    # @param [String] dest_dir
    # @param [Boolean] group  apply group permissions when not falsey
    #   and user is root
    def copy_skeleton_files(src_dir, dest_dir, group = nil)
      rsync = Facter::Core::Execution.which('rsync')
      fail("Error: Could not find 'rsync' command!") unless rsync

      cmd = "#{rsync} -a '#{src_dir}'/ '#{dest_dir}'/ 2>&1"
      cmd = %(sg - #{group} -c '#{rsync} -a --no-g "#{src_dir}/" "#{dest_dir}/" 2>&1') if ENV.fetch('USER') == 'root' && group

      debug("Copying '#{src_dir}' files into '#{dest_dir}'")
      success = execute(cmd)
      unless success
        # process error messages already logged
        msg = "ERROR: Copy of '#{src_dir}' into '#{dest_dir}' failed"
        fail(Simp::Cli::ProcessingError, msg)
      end
    end

    def copy_environment_files(src_env, fail_if_src_missing=true )
      src_env_dir = File.join(@base_environments_path, src_env)
      info("Copying #{@type} env '#{src_env_dir}' to '#{@directory_path}'".cyan)
      if File.directory? src_env_dir
        copy_skeleton_files(src_env_dir, @directory_path)
      elsif fail_if_src_missing
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: Source environment directory '#{src_env_dir}' does not exist to copy!"
        )
      end
    end

    def link_environment_dirs(src_env, fail_if_src_missing=true )
      src_env_dir = File.join(@base_environments_path, src_env)
      if File.directory? src_env_dir
        info("Linking #{@type} env '#{src_env_dir}' to '#{@directory_path}'".cyan)
        FileUtils.ln_s(src_env_dir, @directory_path)
      elsif fail_if_src_missing
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: Source environment directory '#{src_env_dir}' does not exist to link!"
        )
      else
        warn("WARNING: Source environment directory '#{src_env_dir}' does not exist to link; skipping.".yellow)
      end
    end

    def fail_unless_createable
      # Safety feature: Don't clobber an environment directory that already has content
      unless Dir.glob(File.join(@directory_path, '*')).empty?
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: A directory with content already exists at '#{@directory_path}'"
        )
      end
    end
  end
end
