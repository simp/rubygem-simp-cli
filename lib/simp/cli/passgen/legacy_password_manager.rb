require 'highline/import'
require 'simp/cli/logging'
require 'simp/cli/utils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Passgen; end

# Class that provides legacy `simp passgen` operations for environments having
# old simplib module versions that do not support password management beyond
# the simplib::passgen() function.
#
class Simp::Cli::Passgen::LegacyPasswordManager
  require 'fileutils'

  include Simp::Cli::Logging

  attr_reader :location

  # constructor
  # @param environment Puppet environment
  # @param password_dir Location of the password directory to use instead of
  #   the standard directory for the Puppet environment
  #
  # @raise Simp::Cli::ProcessingError if password directory exists and is not
  #   a directory
  #
  def initialize(environment, password_dir = nil)
    @environment = environment
    @puppet_info = Simp::Cli::Utils.puppet_info(@environment)
    if password_dir.nil?
      password_env_dir = File.join(
        @puppet_info[:config]['vardir'], 'simp', 'environments')

      @password_dir = File.join(
        password_env_dir, @environment, 'simp_autofiles', 'gen_passwd')

      @location = "'#{@environment}' Environment"
    else
      @password_dir = password_dir
      @location = @password_dir
    end

    if File.exist?(@password_dir) && !File.directory?(@password_dir)
      err_msg = "Password directory '#{@password_dir}' is not a directory"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end
  end

  #########################################################
  # Password Manager API
  #########################################################

  # @return Array of password names if the password directory exists and any
  #   passwords are present; [] otherwise
  #
  # @raise Simp::Cli::ProcessingError if the password directory cannot be
  #   accessed
  def name_list
    logger.info('Retrieving list of password names using file operations')
    return [] unless Dir.exist?(@password_dir)

    names = nil
    begin
      logger.debug("Searching for password files in #{@password_dir}")
      Dir.chdir(@password_dir) do
        names = Dir.glob('*').select do |x|
          # exclude salt and backup files
          File.file?(x) && (x !~ /\.salt$|\.last$/)
        end
      end
    rescue Exception => e
      err_msg = "List failed: #{e}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    names.sort
  end

  # @return Hash of password information for the specified name
  #
  #   * 'value'- Hash containing 'password' and 'salt' attributes
  #   * 'metadata' - Hash containing a 'history' attribute
  #      * 'history' is an Array of up to the last 10 <password,salt> pairs.
  #        history[0][0] is the most recent password and history[0][1] is its
  #        salt.
  #
  # @param name Password name
  #
  # @raise Simp::Cli::ProcessingError if the files for that name do not
  #   exist or cannot be accessed
  #
  def password_info(name)
    logger.info("Retrieving password info for '#{name}' using file operations")
    current_password_filename = File.join(@password_dir, name)
    unless File.exist?(current_password_filename)
      err_msg = "'#{name}' password not present"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    info = {
      'value'    => {
        'password' => 'UNKNOWN',
        'salt'     => 'UNKNOWN'
      },
      'metadata' => {
        'history' => []
      }
    }

    current_salt_filename = File.join(@password_dir, "#{name}.salt")
    last_password_filename = File.join(@password_dir, "#{name}.last")
    last_salt_filename =  File.join(@password_dir, "#{name}.salt.last")

    begin
      logger.debug("Reading password files for '#{name}' in #{@password_dir}")
      info['value']['password'] = File.read(current_password_filename).chomp
      if File.exist?(current_salt_filename)
        info['value']['salt'] = File.read(current_salt_filename).chomp
      end

      if File.exist?(last_password_filename)
        last_password = File.read(last_password_filename).chomp
        last_salt = 'UNKNOWN'
        if File.exist?(last_salt_filename)
          last_salt = File.read(last_salt_filename).chomp
        end
        info['metadata']['history'] << [ last_password, last_salt ]
      end
    rescue Exception => e
      err_msg = "Retrieve failed: #{e}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    info
  end

  # Remove a password
  #
  # Removes password and salt files for current and previous password
  #
  # @param name Password name
  #
  # @raise Simp::Cli::ProcessingError if the password does not exist or the
  #   removal of any password file fails
  #
  def remove_password(name)
    logger.info("Removing password info for '#{name}' using file operations")
    num_existing_files = 0
    errors = []
    [
      File.join(@password_dir, name),
      File.join(@password_dir, "#{name}.salt"),
      File.join(@password_dir, "#{name}.last"),
      File.join(@password_dir, "#{name}.salt.last")
    ].each do |file|
      if File.exist?(file)
        num_existing_files += 1

        begin
          File.unlink(file)
          logger.debug("Removed '#{file}'")
        rescue Exception => e
          # Will report all problems at end.
          errors << "'#{file}': #{e}"
        end
      end
    end

    if num_existing_files == 0
      err_msg = "'#{name}' password not found"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    unless errors.empty?
      err_msg = "Failed to delete the following password files:\n  " +
        errors.join("\n  ")

      raise Simp::Cli::ProcessingError.new(err_msg)
    end
  end

  # Set a password to a value selected by the user (input or generated)
  #
  # Backups up existing password files and creates a new password file.
  # Does not create a salt file, but relies on simplib::passgen to generate one
  # the next time the catalog is compiled.
  #
  # @param name Name of the password to set
  # @param options Hash of password generation options.
  #   * Required keys:
  #     * :auto_gen - whether to auto-generate new passwords
  #     * :validate - whether to validate new passwords using
  #       libpwquality/cracklib
  #     * :default_length - default password length of auto-generated passwords
  #     * :minimum_length - minimum password length
  #     * :default_complexity - default password complexity of auto-generated
  #       passwords
  #     * :default_complex_only- whether auto-generated passwords should only
  #       contain complex characters
  #
  #   * Optional keys:
  #     * :password - user-provided password; required if :auto_gen=false
  #     * :length - requested length of auto-generated passwords.
  #       * When nil, the password exists, and the existing password length
  #         >='minimum_length', use the length of the existing password
  #       * When nil, the password exists, and the existing password length
  #         < 'minimum_length', use the 'default_length'
  #       * When nil and the password does not exist, use 'default_length'
  #     * :complexity
  #     * :complex_only
  #
  # @return password The new password value
  # @raise Simp::Cli::ProcessingError upon any file operation failure
  #
  def set_password(name, options)
    logger.info("Setting password info for '#{name}' using file operations")
    validate_set_config(options)

    puppet_user = @puppet_info[:config]['user']
    puppet_group = @puppet_info[:config]['group']
    password_filename = File.join(@password_dir, name)
    password = nil
    begin
      password_options = merge_password_options(password_filename, options)
      password, generated = get_new_password(password_options)
      if File.exist?(password_filename)
        backup_password_files(password_filename)
      else
        FileUtils.mkdir_p(@password_dir)
      end

      logger.debug("Writing password to '#{password_filename}'")
      File.open(password_filename, 'w') { |file| file.puts password }

      # Ensure that the ownership and permissions are correct
      FileUtils.chown(puppet_user, puppet_group, password_filename)
      FileUtils.chmod(0640, password_filename)
    rescue Exception => e
      err_msg = "Set failed: #{e}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    password
  end

  #########################################################
  # Helpers
  #########################################################

  # Backup a password file and its salt file
  #
  # Assumes password file exists!
  #
  # @param password_filename Fully qualified name of password file
  #
  # @raise Simp::Cli::ProcessingError if a file move fails
  #
  def backup_password_files(password_filename)
    begin
      backup_filename = password_filename + '.last'
      FileUtils.mv(password_filename, backup_filename, :force => true)
      logger.debug("Moved #{password_filename} to #{backup_filename}")
      salt_filename = password_filename + '.salt'
      if File.exist?(salt_filename)
        backup_filename = salt_filename + '.last'
        FileUtils.mv(salt_filename, backup_filename, :force => true)
        logger.debug("Moved #{salt_filename} to #{backup_filename}")
      end
    rescue Exception => err
      name = File.basename(password_filename)
      err_msg = "Error occurred while backing up '#{name}': #{err}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end
  end

  # Generate password or use password provided by user
  #
  # @param options options for password generation and validation
  #
  # @return [ password, <whether generated> ]
  # @raise Exception of generation/query fails
  #
  def get_new_password(options)
    password = ''
    generated = false
    if options[:auto_gen]
      validate = false
      timeout_seconds = 10
      logger.debug("Generating password with length=#{options[:length]}," +
        " complexity=#{options[:complexity]}," +
        " complex_only=#{options[:complex_only]}," +
        " validate=#{options[:validate]}")

      password = Simp::Cli::Utils.generate_password(options[:length],
        options[:complexity], options[:complex_only], timeout_seconds,
        options[:validate])
      generated = true
    else
      logger.debug('Using user-entered password')
      password = options[:password]
    end

    [ password, generated ]
  end

  # @return copy of options with :length, :complexity, and :complex_only
  #   set to valid values
  #
  # - :length set as follows:
  #   - Use :length in `options` if set and it is not too short
  #   - Otherwise, use length of current password, if the password exists and
  #     the length is not too short
  #   - Otherwise, use :default_length
  # - :complexity is set to :default_complexity, if not set
  # - :complex_only is set to :default_complex_only, if not set
  # - Assumes options have been validated with validate_set_config()
  #
  def merge_password_options(password_file, options)
    password_options = options.dup
    length = nil
    if options[:length].nil?
      if File.exist?(password_file)
        begin
          logger.debug("Reading previous password from #{password_file}" +
            " to determine new password length")
          password = File.read(password_file).chomp
          length = password.length
        rescue Exception => e
          err_msg = "Error occurred while reading '#{password_file}': #{e}"
          raise Simp::Cli::ProcessingError.new(err_msg)
        end
      end
    else
      length = options[:length]
    end

    if length.nil? || (length < options[:minimum_length])
      length = options[:default_length]
    end

    password_options[:length] = length

    if options[:complexity].nil?
      password_options[:complexity] = options[:default_complexity]
    end

    if options[:complex_only].nil?
      password_options[:complex_only] = options[:default_complex_only]
    end

    password_options
  end

  # Verifies options contains the following keys:
  # - :auto_gen
  # - :password (only if :auto_gen=false)
  # - :validate
  # - :default_length
  # - :minimum_length
  # - :default_complexity
  # - :default_complex_only
  #
  # @raise Simp::Cli::ProcessingError if any of the required options is missing
  #
  def validate_set_config(options)
    unless options.key?(:auto_gen)
      err_msg = 'Missing :auto_gen option'
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    unless options[:auto_gen]
      unless options.key?(:password)
        err_msg = 'Missing :password option'
        raise Simp::Cli::ProcessingError.new(err_msg)
      end
    end

    unless options.key?(:validate)
      err_msg = 'Missing :validate option'
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    unless options.key?(:default_length)
      err_msg = 'Missing :default_length option'
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    unless options.key?(:minimum_length)
      err_msg = 'Missing :minimum_length option'
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    unless options.key?(:default_complexity)
      err_msg = 'Missing :default_complexity option'
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    unless options.key?(:default_complex_only)
      err_msg = 'Missing :default_complex_only option'
      raise Simp::Cli::ProcessingError.new(err_msg)
    end
  end

end
