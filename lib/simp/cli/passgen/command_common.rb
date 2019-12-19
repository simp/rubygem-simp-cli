require 'simp/cli/command_console_logger'
require 'simp/cli/exec_utils'
require 'simp/cli/utils'


module Simp; end
class Simp::Cli; end
module Simp::Cli::Passgen; end

# Module containing common functionality needed by
# Simplib::Cli::Commands::Passgen::* commands

module Simp::Cli::Passgen::CommandCommon

  include Simp::Cli::CommandConsoleLogger

  DEFAULT_PUPPET_ENVIRONMENT = 'production'
  DEFAULT_FORCE              = false # true = do not prompt user to confirm operation

  # First simplib version in which simplib::passgen could use libkv
  LIBKV_SIMPLIB_VERSION = '4.0.0'

  AUTO_LOCATION_INFO = <<~AUTO
    Automatically determines the correct location of the passwords for the
    Puppet environment, whether the passwords are stored in a libkv-managed
    key/value store or in legacy files on the local filesystem.
  AUTO

  # @return the appropriate password manager object for the version of
  #   simplib in the environment
  #
  # @raise Simp::Cli::ProcessingError if the Puppet environment does not
  #   exist, the Puppet environment does not have the simp-simplib module
  #   installed, get_simplib_version() fails, or the password manager
  #   constructor fails
  #
  def get_password_manager(opts)
    logger.info("Selecting password manager for '#{opts[:env]}'")
    environments_dir = Simp::Cli::Utils.puppet_info[:config]['environmentpath']
    unless Dir.exist?(File.join(environments_dir, opts[:env]))
      err_msg = "Invalid Puppet environment '#{opts[:env]}': Does not exist"
      raise Simp::Cli::ProcessingError, err_msg
    end

    simplib_version = get_simplib_version(opts[:env])
    if simplib_version.nil?
      err_msg = "Invalid Puppet environment '#{opts[:env]}': " +
        'simp-simplib is not installed'

      raise Simp::Cli::ProcessingError, err_msg
    end

    # construct the correct manager to do the work
    manager = nil
    if legacy_passgen?(simplib_version)
      require 'simp/cli/passgen/legacy_password_manager'

      logger.info('Using legacy password manager')
      # This environment does not have Puppet functions to manage
      # simplib::passgen passwords. Fallback to how these passwords were
      # managed, before.
      manager = Simp::Cli::Passgen::LegacyPasswordManager.new(opts[:env],
        opts[:password_dir])
    else
      require 'simp/cli/passgen/password_manager'

      logger.info('Using password manager that applies simplib::passgen ' +
        'functions')

      # This environment has Puppet functions to manage simplib::passgen
      # passwords, whether they are stored in the legacy directory for the
      # environment or in a key/value store via libkv.  The functions figure
      # out where the passwords are stored and execute appropriate logic.
      manager = Simp::Cli::Passgen::PasswordManager.new(opts[:env],
       opts[:backend],opts[:folder])
    end

    manager
  end

  # @param env Name of Puppet environment
  # @return the version of simplib in the environment or nil if not present
  # @raise Simp::Cli::ProcessingError if `puppet module list` fails for the
  #   specified environment, e.g., if the environment does not exist
  #
  # WARNING: This is fragile.  It depends upon formatted output of a puppet
  # command. Tried to use different structured output formatting, but the
  # results were object dumps and not usable.
  #
  def get_simplib_version(env)
    logger.debug("Checking simplib version in '#{env}'")
    simplib_version = nil
    command = "puppet module list --color=false --environment=#{env}"
    result = Simp::Cli::ExecUtils.run_command(command, false, logger)

    if result[:status]
      regex = /\s+simp-simplib\s+\(v([0-9]+\.[0-9]+\.[0-9]+)\)/m
      match = result[:stdout].match(regex)
      simplib_version = match[1] unless match.nil?
    else
      err_msg = "Unable to determine simplib version in '#{env}' environment"
      raise Simp::Cli::ProcessingError, err_msg
    end

    simplib_version
  end

  # @param env_version Version of simplib in the Puppet environment
  #
  # @return whether the environment has an old version of simplib
  #   that does not provide password-managing Puppet functions
  #
  def legacy_passgen?(env_version)
    env_version.split('.')[0].to_i < LIBKV_SIMPLIB_VERSION.split('.')[0].to_i
  end

  # Translate a boolean command line option into 'enabled' or 'disabled
  # @param option Boolean command line option
  # @return 'enabled' if option == true; 'disabled' otherwise
  #
  def translate_bool(option)
    option ? 'enabled' : 'disabled'
  end
end
