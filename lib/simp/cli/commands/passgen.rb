require 'simp/cli/commands/command'
require 'simp/cli/exec_utils'
require 'simp/cli/logging'
require 'simp/cli/passgen/utils'
require 'simp/cli/utils'
require 'highline/import'

class Simp::Cli::Commands::Passgen < Simp::Cli::Commands::Command

  include Simp::Cli::Logging

  DEFAULT_ENVIRONMENT        = 'production'
  DEFAULT_AUTO_GEN_PASSWORDS = false
  DEFAULT_PASSWORD_LENGTH    = 32
  MINIMUM_PASSWORD_LENGTH    = 8
  DEFAULT_COMPLEXITY         = 0
  DEFAULT_COMPLEX_ONLY       = false
  DEFAULT_FORCE_REMOVE       = false
  DEFAULT_VALIDATE           = false

  # First simplib version in which simplib::passgen could use libkv
  LIBKV_SIMPLIB_VERSION = '4.0.0'

  def initialize
    @operation = nil
    @environment = nil
    @backend = nil       # libkv backend
    @folder = nil        # passgen sub-folder in libkv
    @password_dir = nil  # fully qualified path to a legacy passgen dir
    @names = Array.new
    @password_gen_options = {
     :auto_gen             => DEFAULT_AUTO_GEN_PASSWORDS,
     :validate             => DEFAULT_VALIDATE,
     :length               => nil,
     :default_length       => DEFAULT_PASSWORD_LENGTH,
     :minimum_length       => MINIMUM_PASSWORD_LENGTH,
     :complexity           => nil,
     :default_complexity   => DEFAULT_COMPLEXITY,
     :complex_only         => nil,
     :default_complex_only => DEFAULT_COMPLEX_ONLY
    }
    @force_remove = DEFAULT_FORCE_REMOVE
    @verbose = 0         # Verbosity of console output:
    #                      0 = NOTICE and above
    #                      1 = INFO   and above
    #                      2 = DEBUG  and above
    #                      3 = TRACE  and above  (developer debug)
  end

  #####################################################
  # Simp::Cli::Commands::Command API methods
  #####################################################
  #
  def description
    "Utility for managing 'simplib::passgen' passwords"
  end

  def help
    parse_command_line( [ '--help' ] )
  end

  # @param args Command line options
  def run(args)
    parse_command_line(args)
    return if @help_requested

    # set verbosity threshold for console logging
    set_up_global_logger

    if @operation == :show_environment_list
      show_environment_list
    else
      # space at end tells logger to omit <CR>, so spinner+done is on same line
      logger.notice("Initializing for environment '#{@environment}'... ")
      manager = nil
      Simp::Cli::Utils::show_wait_spinner {
        # construct the correct manager to do the work based on simplib version
        manager = get_password_manager
      }
      logger.notice('done.')

      case @operation
      when :show_name_list
        show_name_list(manager)
      when :show_passwords
        show_passwords(manager, @names)
      when :set_passwords
        set_passwords(manager, @names, @password_gen_options)
      when :remove_passwords
        remove_passwords(manager, @names, @force_remove)
      end
    end
  end

  #####################################################
  # Custom methods
  #####################################################

  # @return Hash Puppet environments in which simp-simplib has been installed
  #   - key is the environment name
  #   - value is the version of simp-simplib
  #
  # @raise Simp::Cli::ProcessingError if `puppet module list` fails
  #   for any Puppet environment
  #
  def find_valid_environments
    # grab the environments path from the production env puppet master config
    environments_dir = Simp::Cli::Utils.puppet_info[:config]['environmentpath']
    environments = Dir.glob(File.join(environments_dir, '*'))
    environments.map! { |env| File.basename(env) }

    # only keep environments that have simplib installed
    env_info = {}
    environments.sort.each do |env|
      simplib_version = get_simplib_version(env)
      env_info[env] =simplib_version unless simplib_version.nil?
    end

    env_info
  end

  # @return the appropriate password manager object for the version of
  #   simplib in the environment
  #
  # @raise Simp::Cli::ProcessingError if the Puppet environment does not
  #   exist, the Puppet environment does not have the simp-simplib module
  #   installed, get_simplib_version() fails, or the password manager
  #   constructor fails
  #
  def get_password_manager
    logger.info("Selecting password manager for '#{@environment}'")
    environments_dir = Simp::Cli::Utils.puppet_info[:config]['environmentpath']
    unless Dir.exist?(File.join(environments_dir, @environment))
      err_msg = "Invalid Puppet environment '#{@environment}': Does not exist"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    simplib_version = get_simplib_version(@environment)
    if simplib_version.nil?
      err_msg = "Invalid Puppet environment '#{@environment}': " +
        'simp-simplib is not installed'

      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    # construct the correct manager to do the work
    manager = nil
    if legacy_passgen?(simplib_version)
      require 'simp/cli/passgen/legacy_password_manager'

      logger.info('Using legacy password manager')
      # This environment does not have Puppet functions to manage
      # simplib::passgen passwords. Fallback to how these passwords were
      # managed, before.
      manager = Simp::Cli::Passgen::LegacyPasswordManager.new(@environment,
        @password_dir)
    else
      require 'simp/cli/passgen/password_manager'

      logger.info('Using password manager that applies simplib::passgen ' +
        'functions')

      # This environment has Puppet functions to manage simplib::passgen
      # passwords, whether they are stored in the legacy directory for the
      # environment or in a key/value store via libkv.  The functions figure
      # out where the passwords are stored and execute appropriate logic.
      manager = Simp::Cli::Passgen::PasswordManager.new(@environment,
        @backend, @folder)
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
      raise Simp::Cli::ProcessingError.new(err_msg)
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

  # @param args Command line arguments
  #
  # @raise OptionsParser::ParseError upon any options parsing or validation
  #   failure
  #
  def parse_command_line(args)
    raise OptionParser::ParseError.new('The SIMP Passgen Tool requires at least one option') if args.empty?

    ###############################################################
    # NOTE TO MAINTAINERS: The help message has been explicitly
    # formatted to fit within an 80-character-wide console window.
    ###############################################################
    #
    opt_parser = OptionParser.new do |opts|
      opts.banner = "\n=== The SIMP Passgen Tool ===."
      opts.separator ''
      opts.separator 'The SIMP Passgen Tool is a simple password control utility. It allows the'
      opts.separator 'viewing, setting, and removal of passwords generated by simplib::passgen.'
      opts.separator ''
      opts.separator '  # Show a list of environments that may have simplib::passgen passwords'
      opts.separator '  simp passgen -E'
      opts.separator ''
      opts.separator '  # Show a list of the password names in the production environment'
      opts.separator '  simp passgen -l'
      opts.separator ''
      opts.separator '  # Show password info for specific passwords in the dev environment'
      opts.separator '  simp passgen -e dev -n NAME1,NAME2,NAME3'
      opts.separator ''
      opts.separator '  # Show password info for a password in a sub-folder in a key/value store.'
      opts.separator "  # This example is for a password from simplib::passgen('app1/admin')"
      opts.separator '  simp passgen -f app1 -n admin'
      opts.separator ''
      opts.separator '  # Remove specific passwords in the test environment.'
      opts.separator '  simp passgen -e test -r NAME1,NAME2'
      opts.separator ''
      opts.separator '  # Set specific passwords in the production environment to values entered'
      opts.separator '  # by the user.'
      opts.separator '  simp passgen -s NAME1,NAME2,NAME3'
      opts.separator ''
      opts.separator '  # Automatically (re)generate specific passwords in the production environment'
      opts.separator '  simp passgen --auto-gen -s NAME1,NAME2,NAME3'
      opts.separator ''
      opts.separator 'COMMANDS:'
      opts.separator ''

      opts.on('-E', '--list-env',
          'List environments that may have passwords.') do
        @operation = :show_environment_list
      end

      opts.on('-l', '--list-names',
          'List password names for the specified',
          'environment.') do
        @operation = :show_name_list
      end

      opts.on('-n', '--name NAME1[,NAME2,...]', Array,
          'Show password info for NAME1[,NAME2,...] in',
          'the specified environment.') do |names|
        @operation = :show_passwords
        @names = names
      end

      opts.on('-r', '--remove NAME1[,NAME2,...]', Array,
          'Remove password info for NAME1[,NAME2,...]',
          'in the specified environment.') do |names|
        @operation = :remove_passwords
        @names = names
      end

      opts.on('-s', '--set NAME1[,NAME2,...]', Array,
          'Set passwords for NAME1[,NAME2,...] in the',
          'specified environment. Current passwords',
          'will be backed up.') do |names|
        @operation = :set_passwords
        @names = names
      end

      # TODO add a --[no]--brief option for showing password info. Want users
      # to have the option to display all available info, especially for
      # libkv-stored passwords. Would default to brief (current behavior).

      opts.on('-h', '--help', 'Print this message.') do
        puts opts
        @help_requested = true
      end

      opts.separator ''
      opts.separator 'COMMAND MODIFIERS:'
      opts.separator ''

      opts.on('--[no-]auto-gen',
          'Whether to auto-generate new passwords.',
          'When disabled the user will be prompted to',
          'enter new passwords. Defaults to ' +
          "#{translate_bool(DEFAULT_AUTO_GEN_PASSWORDS)}.") do |auto_gen|
        @password_gen_options[:auto_gen] = auto_gen
      end

      opts.on('--complexity COMPLEXITY', Integer,
          'Password complexity to use when a password',
          'is auto-generated. For existing passwords',
          'stored in a libkv key/value store, defaults',
          'to the current password complexity.',
          "Otherwise, defaults to #{DEFAULT_COMPLEXITY}.",
          'See simplib::passgen for details.') do |complexity|
        @password_gen_options[:complexity] = complexity
      end

      opts.on('--[no-]complex-only',
          'Whether to only use only complex characters',
          'when a password is auto-generated. For',
          'existing passwords in a libkv key/value',
          'store, defaults to the current password',
          'setting. Otherwise, ' +
          translate_bool(DEFAULT_COMPLEX_ONLY) +
          ' by default.') do |complex_only|
        @password_gen_options[:complex_only] = complex_only
      end


      opts.on('--backend BACKEND',
          'Specific libkv backend to use for',
          'passwords. Rarely needs to be set.') do |backend|
        @backend = backend
      end

      opts.on('-d', '--dir DIR',
          'Fully qualified path to a legacy password',
          'store. Overrides an environment specified',
          "by the '-e' option.") do |dir|
        @password_dir = dir
      end

      opts.on('-e', '--env ENV',
          'Puppet environment to which the operation',
          "will be applied. Defaults to '#{DEFAULT_ENVIRONMENT}'.") do |env|
        @environment = env
      end

      opts.on('--folder FOLDER',
          'Sub-folder in which to find password names',
          'in a libkv key/value store. Defaults to the',
          'top-level folder for simplib::passgen.' ) do |folder|
        @folder = folder
      end

      opts.on('--[no-]force-remove',
          'Remove passwords without prompting user to',
          'confirm. When disabled, the user will be',
          'prompted to confirm the removal for each',
          'password. Defaults to ' +
          "#{translate_bool(DEFAULT_FORCE_REMOVE)}.") do |force_remove|
        @force_remove = force_remove
      end

      opts.on('--length LENGTH', Integer,
            'Password length to use when auto-generated.',
            'Defaults to the current password length,',
            'when the password already exists and its',
            "length is >= #{MINIMUM_PASSWORD_LENGTH}. Otherwise, defaults " +
            "to #{DEFAULT_PASSWORD_LENGTH}.") do |length|
        @password_gen_options[:length] = length
      end

      opts.on('--[no-]validate',
            'Enabled validation of new passwords with',
            'libpwquality/cracklib. **Only** appropriate',
            'for user passwords and does not apply to',
            'passwords generated via simp-simplib',
            'functions (environments with simplib >=',
            "#{LIBKV_SIMPLIB_VERSION}). Defaults to " +
            "#{translate_bool(DEFAULT_VALIDATE)}.") do |validate|
        @password_gen_options[:validate] = validate
      end

      opts.on('-v', '--verbose', 'Verbose console output (stacks).' ) do
        @verbose  += 1
      end

      opts.on('-b', '--[no-]backup',
            'DEPRECATED. This option is no longer',
            'supported. Passwords are always backed up.') do |backup|
        # do nothing
      end
    end


    opt_parser.parse!(args)

    @environment = (@environment.nil? ? DEFAULT_ENVIRONMENT : @environment)
    @names.map! {|name| name.strip }
    @names.delete_if { |name| name.empty? }
    @names.sort!

    unless @help_requested
      if @operation.nil?
        err_msg = "No password operation specified.\n" + opt_parser.help
        raise OptionParser::ParseError.new(err_msg)
      end

      case @operation
      when :show_passwords, :set_passwords, :remove_passwords
        if @names.empty?
          # will only get here if someone passed in names that were all empty
          # strings or only whitespace (i.e., an automated script error)
          type = @operation.to_s.split('_').first
          err_msg = "Only empty names specified for #{type} passwords operation."
          raise OptionParser::ParseError.new(err_msg)
        end
      end
    end
  end

  # Remove a list of passwords
  #
  # @param manager Password manager to use to retrieve password info
  # @param names Array of names(keys) of passwords to remove
  # @param force_remove Whether to remove password files without prompting
  #   the user to verify the removal operation
  #
  # @raise Simp::Cli::ProcessingError if unable remove all passwords
  #
  def remove_passwords(manager, names, force_remove)
    errors = []
    names.each do |name|
      remove = force_remove
      unless force_remove
        prompt = "Are you sure you want to remove all info for '#{name}'?".bold
        remove = Simp::Cli::Passgen::Utils::yes_or_no(prompt, false)
      end

      if remove
        # space at end tells logger to omit <CR>, so spinner+done is on same
        # line
        logger.notice("Processing '#{name}' in #{manager.location}... ")
        begin
          Simp::Cli::Utils::show_wait_spinner {
            manager.remove_password(name)
          }
          logger.notice('done.')
          logger.notice("  Removed '#{name}'")
        rescue Exception => e
          logger.notice('done.')
          logger.notice("  Skipped '#{name}'")
          errors << "'#{name}': #{e}"
        end
      else
        logger.notice("Skipped '#{name}' in #{manager.location}")
      end

      logger.notice
    end

    unless errors.empty?
      err_msg = "Failed to remove the following passwords in" +
       " #{manager.location}:\n  #{errors.join("\n  ")}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end
  end

  # Set a list of passwords to values selected by the user
  #
  # @param manager Password manager to use to retrieve password info
  # @param names Array of names(keys) of passwords to remove
  # @param password_gen_options Hash of password generation options
  #
  # @raise Simp::Cli::ProcessingError if unable to set all passwords
  #
  def set_passwords(manager, names, password_gen_options)
    errors = []
    names.each do |name|
      # space at end tells logger to omit <CR>, so spinner+done is on same line
      logger.notice("Processing '#{name}' in #{manager.location}... ")
      begin
        unless password_gen_options[:auto_gen]
          validate = password_gen_options[:validate]
          logger.debug("Gathering password with validate=#{validate}")
          password_gen_options[:password] =
            Simp::Cli::Passgen::Utils::get_password(5, validate)
        end

        password = nil
        Simp::Cli::Utils::show_wait_spinner {
          password = manager.set_password(name, password_gen_options)
        }
        logger.notice('done.')
        logger.notice("  '#{name}' new password: #{password}")
      rescue Exception => e
        logger.notice('done.')
        logger.notice("  Skipped '#{name}'")
        errors << "'#{name}': #{e}"
      end

      logger.notice
    end

    unless errors.empty?
      err_msg = "Failed to set #{errors.length} out of #{names.length}" +
        " passwords in #{manager.location}:\n  #{errors.join("\n  ")}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end
  end

  # Set console log level
  def  set_up_global_logger
   case @verbose
    when 0
      console_log_level = :notice
    when 1
      console_log_level = :info
    when 2
      console_log_level = :debug
    else
      console_log_level = :trace # developer debug
    end
    logger.levels(console_log_level)
  end

  # Prints to the console the list of Puppet environments for which
  # simp-simplib is installed
  #
  # @raise Simp::Cli::ProcessingError if `puppet module list` fails
  #   for any Puppet environment
  #
  def show_environment_list
    # space at end tells logger to omit <CR>, so spinner+done is on same line
    logger.notice('Looking for environments with simp-simplib installed... ')
    valid_envs = nil
    Simp::Cli::Utils::show_wait_spinner {
      valid_envs = find_valid_environments
    }
    logger.notice('done.')

    logger.notice
    if valid_envs.empty?
      logger.notice('No environments with simp-simplib installed were found.')
    else
      title = 'Environments'
      logger.notice(title)
      logger.notice('='*title.length)
      logger.notice( valid_envs.keys.sort.join("\n"))
    end
    logger.notice
  end

  # Print the list of passwords found to the console
  #
  # @param manager Password manager to use to retrieve password info
  #
  # @raise Simp::Cli::ProcessingError if retrieval of password list fails
  #
  def show_name_list(manager)
    # space at end tells logger to omit <CR>, so spinner+done is on same line
    logger.notice('Retrieving password names... ')
    begin
      names = nil
      Simp::Cli::Utils::show_wait_spinner {
        names = manager.name_list
      }
      logger.notice('done.')

      logger.notice
      if names.empty?
        logger.notice("No passwords found in #{manager.location}")
      else
        title = "#{manager.location} Password Names"
        logger.notice(title)
        logger.notice('='*title.length)
        logger.notice(names.join("\n"))
      end
      logger.notice
    rescue Exception => e
      err_msg = "List for #{manager.location} failed: #{e}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end
  end

  # Prints password info to the console.
  #
  # For each password name, prints its current value, and when present, its
  # previous value.
  #
  # @param manager Password manager to use to retrieve password info
  # @param names Names of passwords to be printed
  #
  # @raise Simp::Cli::ProcessingError if unable to retrieve password
  #   info for all names
  #
  def show_passwords(manager, names)
    # space at end tells logger to omit <CR>, so spinner+done is on same line
    logger.notice("Retrieving password information... ")
    results = []
    errors = []
    Simp::Cli::Utils::show_wait_spinner {
      names.each do |name|
        results << "Name: #{name}"
        begin
          info = manager.password_info(name)
          results << "  Current:  #{info['value']['password']}"
          unless info['metadata']['history'].empty?
            results << "  Previous: #{info['metadata']['history'][0][0]}"
          end
        rescue Exception => e
          results << '  Skipped'
          errors << "'#{name}': #{e}"
        end
        results << ''
      end
    }
    logger.notice('done.')

    logger.notice
    title = "#{manager.location} Passwords"
    logger.notice(title)
    logger.notice('='*title.length)
    results.each { |line| logger.notice(line) }

    unless errors.empty?
      err_msg = "Failed to retrieve #{errors.length} out of #{names.length}" +
        " passwords in #{manager.location}:\n  #{errors.join("\n  ")}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end
  end

  # Translate a boolean command line option into 'enabled' or 'disabled
  # @param option Boolean command line option
  # @return 'enabled' if option == true; 'disabled' otherwise
  #
  def translate_bool(option)
    option ? 'enabled' : 'disabled'
  end
end
