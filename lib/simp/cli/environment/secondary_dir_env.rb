# frozen_string_literal: true

require 'simp/cli/environment/dir_env'
require 'fileutils'

# Environment helper namespace
module Simp::Cli::Environment
  # Manages a "Secondary" SIMP directory environment
  # @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/760840207/Environments
  class SecondaryDirEnv < DirEnv
    def initialize(name, base_environments_path, opts)
      super(:secondary, name, base_environments_path, opts)
      @skeleton_path = opts[:skeleton_path] || fail(ArgumentError, 'No :skeleton_path in opts')

      @rsync_dest_path = File.join(@directory_path, 'rsync')
      @rsync_skeleton_path = opts[:rsync_skeleton_path] || fail(ArgumentError, 'No :rsync_skeleton_path in opts')

      tftpboot_dest_path = @opts[:tftpboot_dest_path] || fail(ArgumentError, 'No :tftpboot_dest_path in opts')
      @tftpboot_dest_path = File.join(@directory_path, tftpboot_dest_path)
      @tftpboot_src_path  = @opts[:tftpboot_src_path] || fail(ArgumentError, 'No :tftpboot_src_path in opts')

      @fakeca_dest_path   = File.join(@directory_path, 'FakeCA')

      # NOTE: This 60-byte key size matches the logic in `gencerts_common.sh`.
      # The previous simp-environment RPM's %post logic (mapping: A5.2) created
      # a much smaller 24-byte key:
      #
      #   https://github.com/simp/simp-environment-skeleton/blob/6.3.0/build/simp-environment.spec#L192-L196
      #
      @cacertkey_bytesize = 60
    end

    # Create a new environment
    #
    #   - [x] A1.2 create directory from skeletons in /usr/share/simp/environment-skeleton
    #     - [x] C1.2 copy rsync files to ${ENVIRONMENT}/rsync/
    #     - [x] C2.1 copy rsync files to ${ENVIRONMENT}/rsync/
    #        - [?] this should include any logic needed to ensure a basic DNS environment
    #     - [x] A5.2 ensure a `cacertkey` exists for FakeCA
    #        - Should this also be in fix()?
    #     - [x] D1.1 install tftp PXE boot files into the appropriate directory, when found
    #
    #   - Not implemented, because it's scope creep:
    #     - [?] this should include any logic needed to ensure a basic DNS environment
    #
    # @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/edit/757497857#simp_cli_environment_changes
    def create
      fail_unless_createable

      case @opts[:strategy]
      when :skeleton
        create_environment_from_skeletons
      when :copy
        copy_environment_files(@opts[:src_env])
      when :link
        link_environment_dirs(@opts[:src_env])
      else
        fail("ERROR: Unknown Secondary environment create strategy: '#{@opts[:strategy]}'")
      end
    end

    # Fix consistency of environment
    #
    #   - [x] if environment is not available (#{@directory_path} not found)
    #      - [x] fail with helpful message
    #   - [x] A2.2 apply SELinux fixfiles restore to the ${ENVIRONMENT}/ + subdirectories
    #   - [x] A2.3 apply the correct SELinux contexts on demand
    #   - [x] A3.2.2 apply Puppet group ownership to $ENVIRONMENT/site_files/
    #   - [x] C3.2 ensure correct FACLS
    #
    # @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/edit/757497857#simp_cli_environment_changes
    def fix
      <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():

      TODO

      # if environment is not available, fail with helpful message
      unless File.directory? @directory_path
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: secondary directory not found at '#{@directory_path}'"
        )
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

      # apply Puppet group ownership to $ENVIRONMENT (NOT recursive)
      apply_puppet_permissions(File.join(@directory_path), false, true, false)

      # ensure correct FACLS on rsync/ files
      #
      #   previous impl: https://github.com/simp/simp-rsync-skeleton/blob/6.2.1/build/simp-rsync.spec#L98-L99
      #
      apply_facls(@rsync_dest_path, File.join(@rsync_dest_path, '.rsync.facl'))
    end

    # Apply FACL permissions to a path using a file for `setfacl --restore`
    # @param [String] path       absolute path set FACLs
    # @param [String] facl_file  absolute path to rsync facl rules
    def apply_facls(path, facl_file)
      unless File.exist? @directory_path
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: Path does not exist to set FACLS: '#{path}'"
        )
      end
      fail(Simp::Cli::ProcessingError, "ERROR: No FACL file at '#{facl_file}'") unless File.exist?(facl_file)

      Dir.chdir(path) do
        info("Applying FACL rules to '#{path}'".cyan)
        cmd = "setfacl --restore=#{facl_file}"
        unless execute(cmd)
          fail(Simp::Cli::ProcessingError, "ERROR:  Failed to apply FACL rules to #{path}")
        end
      end
    end

    def create_environment_from_skeletons
      info("Creating #{@type} env '#{@directory_path}' from '#{@skeleton_path}'".cyan)

      # make sure directory exists and is readable by all
      FileUtils.mkdir_p @directory_path, mode: 0755
      FileUtils.chmod(0755, File.dirname(@directory_path))
      FileUtils.chmod(0755, File.dirname(File.dirname(@directory_path)))

      copy_skeleton_files(@skeleton_path, @directory_path)        # A1.2
      copy_rsync_skeleton_files                                   # C1.2, C2.1, C.5.2
      copy_tftpboot_files                                         # D1.1
      create_fakeca_cacert_key                                    # A5.2
    end

    # Copy rsync skeleton files and create rsync/CentOS link to rsync/RedHat
    def copy_rsync_skeleton_files
      info("Copying rsync skeleton files from '#{@rsync_skeleton_path} into #{@type} env".cyan)
      copy_skeleton_files(@rsync_skeleton_path, @rsync_dest_path) # C1.2, C2.1
      Dir.chdir(@rsync_dest_path) do
        FileUtils.ln_s('RedHat', 'CentOS')  # C.5.2
      end
    end

    # Copy each `unpack_dvd`-installed OS's tftpboot PXE images into the
    # environment's rsync tftpboot directory
    #
    #   prev impl: https://github.com/simp/simp-core/blob/e8e9cb2db4a2a904275ec4ed82aff3fba32161b1/build/distributions/CentOS/7/x86_64/DVD/ks/dvd/auto.cfg#L165-L190
    #
    def copy_tftpboot_files
      Dir.glob(@tftpboot_src_path) do |dir|
        info("Copying tftpboot PXE image files from '#{dir}' into #{@type} env".cyan)
        os_info = dir.split('/')[-5..-3]
        dst_dirname = os_info.map(&:downcase).join('-')
        dst_path = File.join(@tftpboot_dest_path, dst_dirname)
        copy_skeleton_files(dir, dst_path, 'nobody')
        # change perms to world readable or tftp fails
        Dir.chdir(dst_path) do
          FileUtils.chmod(0644, Dir.entries(dst_path) - %w[. ..])
        end


        # create major OS version link
        os_info[1] = os_info[1].split('.').first
        Dir.chdir(@tftpboot_dest_path) do
          FileUtils.ln_s(dst_dirname, os_info.map(&:downcase).join('-'))
        end
      end
    end

    # Create a new FakeCA cacertkey file, populated with random gibberish
    #
    #   prev impl: https://github.com/simp/simp-environment-skeleton/blob/6.3.0/build/simp-environment.spec#L192-L196
    #
    def create_fakeca_cacert_key
      fail(Simp::Cli::ProcessingError, "No FakeCA directory at '#{@fakeca_dest_path}'") unless File.directory? @fakeca_dest_path

      cacertkey_path = File.join(@fakeca_dest_path, 'cacertkey')
      info("Creating in FakeCA cacertkey in #{@type} env at '#{cacertkey_path}'".cyan)
      require 'securerandom'
      require 'base64'
      File.open(cacertkey_path, 'w') do |f|
        f.print Base64.strict_encode64(SecureRandom.bytes(@cacertkey_bytesize))
      end
    end
  end
end
