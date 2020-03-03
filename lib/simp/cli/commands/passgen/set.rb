require 'simp/cli/commands/command'
require 'simp/cli/passgen/command_common'
require 'simp/cli/passgen/utils'

class Simp::Cli::Commands::Passgen::Set < Simp::Cli::Commands::Command

  include Simp::Cli::Passgen::CommandCommon

  DEFAULT_AUTO_GEN_PASSWORDS = false
  DEFAULT_PASSWORD_LENGTH    = 32
  MINIMUM_PASSWORD_LENGTH    = 8
  DEFAULT_COMPLEXITY         = 0
  DEFAULT_COMPLEX_ONLY       = false
  DEFAULT_VALIDATE           = false

  # First simplib version in which simplib::passgen could use simpkv
  SIMPKV_SIMPLIB_VERSION = '4.0.0'

  def initialize
    @opts = {
      :env          => DEFAULT_PUPPET_ENVIRONMENT,
      :backend      => nil, # simpkv backend
      :folder       => nil, # passgen sub-folder in simpkv
      :names        => [],  # names of passwords to set
      :gen_options  => {    # password generation options
        :auto_gen             => DEFAULT_AUTO_GEN_PASSWORDS,
        :validate             => DEFAULT_VALIDATE,
        :length               => nil,
        :default_length       => DEFAULT_PASSWORD_LENGTH,
        :minimum_length       => MINIMUM_PASSWORD_LENGTH,
        :complexity           => nil,
        :default_complexity   => DEFAULT_COMPLEXITY,
        :complex_only         => nil,
        :default_complex_only => DEFAULT_COMPLEX_ONLY
      },
      :password_dir => nil, # fully qualified path to a legacy passgen dir
      :verbose      => 0    # Verbosity of console output:
      #                        -1 = ERROR  and above
      #                         0 = NOTICE and above
      #                         1 = INFO   and above
      #                         2 = DEBUG  and above
      #                         3 = TRACE  and above  (developer debug)
    }
  end

  #####################################################
  # Simp::Cli::Commands::Command API methods
  #####################################################
  #
  def self.description
    "Set 'simplib::passgen' passwords"
  end

  def help
    parse_command_line( [ '--help' ] )
  end

  # @param args Command line options
  def run(args)
    parse_command_line(args)
    return if @help_requested

    # set verbosity threshold for console logging
    set_up_global_logger(@opts[:verbose])

    # space at end tells logger to omit <CR>, so spinner+done are on same line
    logger.notice("Initializing for environment '#{@opts[:env]}'... ")
    manager = nil
    Simp::Cli::Utils::show_wait_spinner {
      # construct the correct manager to do the work based on simplib version
      manager = get_password_manager(@opts)
    }
    logger.notice('done.')

    set_passwords(manager, @opts[:names], @opts[:gen_options])
  end

  #####################################################
  # Custom methods
  #####################################################

  # @param args Command line arguments
  #
  # @raise OptionsParser::ParseError upon any options parsing or validation
  #   failure
  # @raise Simp::Cli::ProcessingError if the list of passwords to set is
  #   missing from args
  #
  def parse_command_line(args)
    ###############################################################
    # NOTE TO MAINTAINERS: The help message has been explicitly
    # formatted to fit within an 80-character-wide console window.
    ###############################################################
    #
    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp passgen set [options]'
      opts.separator <<~HELP_MSG

        #{self.class.description}.

        #{AUTO_LOCATION_INFO}
        USAGE:
          simp passgen set -h
          simp passgen set NAME1,NAME2,... [--[no]-validate] [-e ENV] \\
            [--backend BACKEND|-d DIR] [-v|-q]

          simp passgen set NAME1,NAME2,... --auto-gen [--complexity COMPLEXITY] \\
            [--[no]-complex-only] [--length LENGTH] [-e ENV] \\
            [--backend BACKEND|-d DIR] [-v|-q]

        EXAMPLES:
          # Set specific passwords in the production environment to values entered
          # by the user
          simp passgen set app1_admin,app2_auth

          # Automatically generate specific passwords in the dev environment, using
          # existing password settings for each password, if available, and defaults
          # otherwise
          simp passgen set app1_admin,app2_auth --auto-gen -e dev

          # Automatically generate specific passwords in the dev environment, using
          # explicit password settings
          simp passgen set app1_admin,app2_auth --auto-gen --complexity 2 --complex-only \\
            --length 48 -e dev

        OPTIONS:
      HELP_MSG

      opts.on('--[no-]auto-gen',
              'Whether to auto-generate new passwords.',
              'When disabled the user will be prompted to',
              'enter new passwords. Defaults to '\
              "#{translate_bool(@opts[:gen_options][:auto_gen])}.") do |auto_gen|
        @opts[:gen_options][:auto_gen] = auto_gen
      end

      opts.on('--complexity COMPLEXITY', Integer,
              'Password complexity to use when a password',
              'is auto-generated. For existing passwords',
              'stored in a simpkv key/value store, defaults',
              'to the current password complexity.',
              'Otherwise, defaults to '\
              "#{@opts[:gen_options][:default_complexity]}.",
              'See simplib::passgen for details.') do |complexity|
        @opts[:gen_options][:complexity] = complexity
      end

      opts.on('--[no-]complex-only',
              'Whether to only use only complex characters',
              'when a password is auto-generated. For',
              'existing passwords in a simpkv key/value',
              'store, defaults to the current password',
              'setting. Otherwise, ' +
              translate_bool(@opts[:gen_options][:default_complex_only]) +
              ' by default.') do |complex_only|
        @opts[:gen_options][:complex_only] = complex_only
      end


      opts.on('--backend BACKEND',
              'Specific simpkv backend to use for',
              'passwords. Rarely needs to be set.',
              'Overrides the appropriate backend',
              'for the environment.') do |backend|
        @opts[:backend] = backend
      end

      opts.on('-d', '--dir DIR',
              'Fully qualified path to a legacy password',
              'store. Rarely needs to be set. Overrides',
              'the directory for the environment.') do |dir|
        @opts[:password_dir] = dir
      end

      opts.on('-e', '--env ENV',
              'Puppet environment to which the operation',
              "will be applied. Defaults to '#{@opts[:env]}'.") do |env|
        @opts[:env] = env
      end

      opts.on('--length LENGTH', Integer,
            'Password length to use when auto-generated.',
            'Defaults to the current password length,',
            'when the password already exists and its',
            "length is >= #{@opts[:gen_options][:minimum_length]}. "\
            "Otherwise, defaults to "\
            "#{@opts[:gen_options][:default_length]}.") do |length|
        @opts[:gen_options][:length] = length
      end

      opts.on('--[no-]validate',
            'Enabled validation of new passwords with',
            'libpwquality/cracklib. **Only** appropriate',
            'for user passwords and does not apply to',
            'passwords generated via simp-simplib',
            'functions (environments with simplib >=',
            "#{SIMPKV_SIMPLIB_VERSION}). Defaults to "\
            "#{translate_bool(@opts[:gen_options][:validate])}.") do |validate|
        @opts[:gen_options][:validate] = validate
      end

      add_logging_command_options(opts, @opts)

      opts.on('-h', '--help', 'Print this message.') do
        puts opts
        @help_requested = true
      end

    end

    remaining_args = opt_parser.parse!(args)

    unless @help_requested
      if remaining_args.empty?
        err_msg = 'Password names are missing from command line'
        raise Simp::Cli::ProcessingError, err_msg
      else
        @opts[:names] = remaining_args[0].split(',').sort
      end
    end
  end

  # Set a list of passwords to values selected by the user
  #
  # @param manager Password manager to use to retrieve password info
  # @param names Array of names(keys) of passwords to set
  # @param password_gen_options Hash of password generation options
  #
  # @raise Simp::Cli::ProcessingError if unable to set all passwords
  #
  def set_passwords(manager, names, password_gen_options)
    errors = []
    names.each do |name|
      # space at end tells logger to omit <CR>, so spinner+done are on same line
      logger.notice("Processing '#{name}' in #{manager.location}... ")
      begin
        unless password_gen_options[:auto_gen]
          validate = password_gen_options[:validate]
          min_length = password_gen_options[:minimum_length]
          logger.debug("Gathering password with validate=#{validate} " +
            "min_length=#{min_length}")

          password_gen_options[:password] =
            Simp::Cli::Passgen::Utils::get_password(5, validate, min_length)
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
      raise Simp::Cli::ProcessingError, err_msg
    end
  end
end
