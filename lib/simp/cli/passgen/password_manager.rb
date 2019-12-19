require 'highline/import'
require 'simp/cli/apply_utils'
require 'simp/cli/exec_utils'
require 'simp/cli/logging'
require 'simp/cli/utils'
require 'tmpdir'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Passgen; end

class Simp::Cli::Passgen::PasswordManager

  include Simp::Cli::Logging

  attr_reader :location

  def initialize(environment, backend, folder)
    @environment = environment
    @backend = backend
    @folder = folder
    @puppet_info = Simp::Cli::Utils.puppet_info(@environment)

    @location = "'#{@environment}' Environment"
    if @folder or @backend
      qualifiers = []
      qualifiers << "'#{@folder}' Folder" if @folder
      qualifiers << "'#{@backend}' libkv Backend" if @backend
      @location += ", #{qualifiers.join(', ')}"
    end

    @custom_options = @backend.nil? ? nil : "{ 'backend' => '#{@backend}' }"

    @list = nil
  end

  #####################################################
  # Password Manager API
  #####################################################
  #
  # @return Array of password names if any are present; [] otherwise
  #
  # @raise Simp::Cli::ProcessingError if the password list operation failed or
  #   information retrieved is malformed
  def name_list
    logger.info('Retrieving list of password names with simplib::passgen' +
      'functions')

    begin
      password_list.key?('keys') ? password_list['keys'].keys.sort : []
    rescue Exception => e
      err_msg = "List failed: #{e}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end
  end

  # @return Hash of password information for the specified name
  #
  #   * 'value'- Hash containing 'password' and 'salt' attributes
  #   * 'metadata' - Hash containing a 'history' attribute, and when available,
  #     'complexity' and 'complex_only' attributes
  #      * 'history' is an Array of up to the last 10 <password,salt> pairs.
  #        history[0][0] is the most recent password and history[0][1] is its
  #        salt.
  #
  # @param name Password name
  #
  # @raise Simp::Cli::ProcessingError if the password does not exist or the
  #   info cannot be retrieved
  #
  def password_info(name)
    logger.info("Retrieving password info for '#{name}' using " +
      'simplib::passgen functions')

    begin
      fullname = @folder.nil? ? name : "#{@folder}/#{name}"
      info = current_password_info(fullname)

      if info.empty?
        err_msg = "'#{name}' password not found"
        raise Simp::Cli::ProcessingError.new(err_msg)
      end

      # make sure results are something we can process...should only have a
      # problem if simplib::passgen::get changes and this software was not
      # updated
      unless valid_password_info?(info)
        err_msg = 'Invalid result returned from simplib::passgen::get:' +
          "\n\n#{info}"

        raise Simp::Cli::ProcessingError.new(err_msg)
      end
    rescue Exception => e
      err_msg = "Retrieve failed: #{e}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    info
  end

  # Remove a password
  #
  # @param name Password name
  #
  # @raise Simp::Cli::ProcessingError if the password does not exist or the
  #   remove fails
  #
  def remove_password(name)
    logger.info("Removing password info for '#{name}' using simplib::passgen " +
      'functions')

    fullname = @folder.nil? ? name : "#{@folder}/#{name}"
    args = "'#{fullname}'"
    args += ", #{@custom_options}" if @custom_options
    failure_message = "'#{name}' password not found"
    manifest = <<~EOM
      if empty(simplib::passgen::get(#{args})) {
        fail("#{failure_message}")
      } else {
        simplib::passgen::remove(#{args})
      }
    EOM

    logger.debug("Removing the password info for '#{fullname}' with a manifest")
    opts = apply_options('Password remove', failure_message)
    begin
      Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
    rescue => e
      err_msg = "Remove failed: #{e.message}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end
  end

  # Set a password to a value selected by the user (input or generated)
  #
  # Generates a companion salt and then sets the password and its salt.
  #
  # @param name Name of the password to set
  # @param options Hash of password generation options
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
  #
  # @return password The new password value
  # @raise Simp::Cli::ProcessingError upon any failure
  #
  def set_password(name, options)
    logger.info("Setting password info for '#{name}' using simplib::passgen " +
      'functions')

    validate_set_config(options)

    password = nil
    begin
      fullname = @folder.nil? ? name : "#{@folder}/#{name}"
      password_options = merge_password_options(fullname, options)
      if options[:auto_gen]
        password = generate_and_set_password(fullname, password_options)
      else
        password = get_and_set_password(fullname, password_options)
      end
    rescue Exception => e
      err_msg = "Set failed: #{e}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    password
  end

  #####################################################
  # Helpers
  #####################################################

  # @return options appropriate for puppet apply via
  #   Simp::Cli::ApplyUtils::apply_manifest_with_spawn
  #
  # @param title Brief description of operation to use in error reporting
  # @param failure_message Error message to search for in the stderr output of
  #    a failed apply and then use as the (simplified) failure message if found
  #lib/simp/cli/kv/info_validator.rb
  def apply_options(title, failure_message=nil)
    opts = {
      :title         => title,
      :env           => @environment,
      :fail          => true,
      :group         => @puppet_info[:config]['group'],
      :puppet_config => { 'vardir' => @puppet_info[:config]['vardir'] }
    }

    opts[:fail_filter] = failure_message unless failure_message.nil?
    opts
  end

  # Retrieve the current password info for a name
  #
  # @param fullname The full password name.  For legacy passgen, this is simply
  #   the password name. For libkv, this is the password name prepended with
  #   the folder, as appropriate.
  #
  # @return Hash of password information returned by simplib::passgen::get
  #
  # @raise Simp::Cli::ProcessingError if apply of manifest running
  #   simplib::passgen::get fails or the resulting YAML file containing the
  #   password info cannot be read
  #
  def current_password_info(fullname)
    logger.debug("Retrieving current password info for '#{fullname}'" +
      ' with a manifest')

    tmpdir = Dir.mktmpdir( File.basename( __FILE__ ) )
    password_info = nil
    begin
      args = "'#{fullname}'"
      args += ", #{@custom_options}" if @custom_options
      # persist to file, because log scraping is fragile
      result_file = File.join(tmpdir, 'password_info.yaml')
      manifest =<<~EOM
        $password_info = simplib::passgen::get(#{args})
        file { '#{result_file}': content => to_yaml($password_info) }
      EOM

      opts = apply_options('Current password retrieve')
      Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
      password_info = Simp::Cli::ApplyUtils::load_yaml(result_file,
        'password info', logger)
    ensure
      FileUtils.remove_entry_secure(tmpdir)
    end

    password_info
  end

  # Autogenerate both a password and companion salt and then set the
  # <password,salt> pair.
  #
  # This is done entirely via simplib functions.
  #
  # In simplib::passgen::set, note the following:
  # * 'user' option is essential for legacy password files or the generated
  #    files will be owned by root and fail simplib::passgen's file validation.
  # * 'complexity' and 'complex_only' are required in libkv mode; persisted with
  #    the password, salt, and history in libkv mode; and unused in legacy mode.
  #
  # @param fullname The full password name.  For legacy passgen, this is simply
  #   the password name. For libkv, this is the password name prepended with
  #   the folder, as appropriate.
  #
  # @param options Password generation options
  #   * :length, :complexity, and :complex_only are used by
  #     simplib::passgen::gen_password_and_salt
  #     password
  #   * :validate is **NOT** used
  #
  # @return generated password
  #
  def generate_and_set_password(fullname, options)
    logger.debug("Generating and setting the password and salt for" +
      " '#{fullname}' with password length=#{options[:length]}," +
        " complexity=#{options[:complexity]}, and" +
        " complex_only=#{options[:complex_only]}" +
        " via a manifest")

    tmpdir = Dir.mktmpdir( File.basename( __FILE__ ) )
    password = nil
    begin
      # persist password to file for retrieval, because log scraping is fragile
      result_file = File.join(tmpdir, 'password.txt')
      generate_timeout_seconds = 30
      custom_options = @custom_options ? ", #{@custom_options}" : ''
      manifest =<<~EOM
        [ $password, $salt ] = simplib::passgen::gen_password_and_salt(
          #{options[:length]}, # length
          #{options[:complexity]}, # complexity
          #{options[:complex_only]}, # complex_only
          #{generate_timeout_seconds}) # generate timeout seconds

        $password_options = {
          'complexity'   => #{options[:complexity]},
          'complex_only' => #{options[:complex_only]},
          'user'         => '#{@puppet_info[:config]['user']}'
        }

        simplib::passgen::set('#{fullname}', $password, $salt,
          $password_options#{custom_options})

        file { '#{result_file}': content => $password }
      EOM

      opts = apply_options('Password generate and set')
      Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
      begin
        password = File.read(result_file)
      rescue Exception => e
        err_msg = "Failed to read generated password: #{e}"
        raise Simp::Cli::ProcessingError.new(err_msg)
      end
    ensure
      FileUtils.remove_entry_secure(tmpdir)
    end
    password
  end

  # Retrieve user-provided password, generate a salt for it and then set the
  # <password,salt> pair.
  #
  # The salt generation and setting of the pair is done via simplib functions.
  #
  # In simplib::passgen::set, note the following:
  # * 'user' option is essential for legacy password files or the generated
  #    files will be owned by root and fail simplib::passgen's file validation.
  # * 'complexity' and 'complex_only' are required in libkv mode; persisted with
  #    the password, salt, and history in libkv mode; and unused in legacy mode.
  # * The odd looking escape of single quotes is required because
  #   \' is a back reference in gsub.
  #
  # @return user-supplied password
  def get_and_set_password(fullname, options)
    logger.debug('Using user-entered password')
    password = options[:password]

    logger.debug("Generating the salt and setting the password and salt for" +
      " '#{fullname}' with a manifest")

    custom_options = @custom_options ? ", #{@custom_options}" : ''
    manifest =<<~EOM
      $salt = simplib::passgen::gen_salt(30)  # 30 second generate timeout
      $password_options = {
        'complexity'   => #{options[:complexity]},
        'complex_only' => #{options[:complex_only]},
        'user'         => '#{@puppet_info[:config]['user']}'
      }

      simplib::passgen::set('#{fullname}', '#{password.gsub("'", "\\\\'")}',
        $salt, $password_options#{custom_options})
    EOM

    opts = apply_options('Password set')
    Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
    password
  end

  # @return copy of options with :length, :complexity, and :complex_only
  #   set to valid values
  #
  # - :length set as follows:
  #   - Use :length in `options` if set and it is not too short
  #   - Otherwise, use length of current password, if the password exists and
  #     the length is not too short.
  #   - Otherwise, use :default_length
  # - :complexity is set as follows:
  #   - Use :complexity in `options` if set
  #   - Otherwise, use complexity of the current password, if the password
  #     exists and the complexity is available
  #   - Otherwise, use :default_complexity
  # - :complex_only is set to :default_complex_only, if not set
  #   - Use :complex_only in `options` if set
  #   - Otherwise, use complex_only of the current password, if the password
  #     exists and the complex_only is available
  #   - Otherwise, use :default_complex_only
  # - Assumes options have been validated with validate_set_config()
  #
  def merge_password_options(fullname, options)
    password_options = options.dup
    current = current_password_info(fullname)

    if options[:length].nil?
      if current.key?('value')
        password_options[:length] = current['value']['password'].length
      else
        password_options[:length] = options[:default_length]
      end
    end

    if password_options[:length] < options[:minimum_length]
      password_options[:length] = options[:default_length]
    end

    if options[:complexity].nil?
      if ( current.key?('metadata') && current['metadata'].key?('complexity') )
        password_options[:complexity] = current['metadata']['complexity']
      else
        password_options[:complexity] = options[:default_complexity]
      end
    end

    if options[:complex_only].nil?
      if ( current.key?('metadata') && current['metadata'].key?('complex_only') )
        password_options[:complex_only] = current['metadata']['complex_only']
      else
        password_options[:complex_only] = options[:default_complex_only]
      end
    end

    password_options
  end


  # Retrieve and validate a list of a password folder
  #
  # @raise if manifest apply to retrieve the list fails, the manifest result
  #   cannot be parsed as YAML, or the result does not have the required keys
  #
  def password_list
    tmpdir = Dir.mktmpdir( File.basename( __FILE__ ) )
    list = nil
    begin
      args = ''
      folder = @folder.nil? ? '/' : @folder
      if @custom_options
        args = "'#{folder}', #{@custom_options}"
      else
        args = "'#{folder}'"
      end

      logger.debug("Listing passwords in '#{folder}' passgen folder with " +
        'a manifest')

      # persist to file, because content may be large and log scraping
      # is fragile
      result_file = File.join(tmpdir, 'list.yaml')
      manifest =<<~EOM
        $list = simplib::passgen::list(#{args})
        file { '#{result_file}': content => to_yaml($list) }
      EOM

      opts = apply_options('Password list')
      Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
      list = Simp::Cli::ApplyUtils::load_yaml(result_file, 'password list',
        logger)

      # make sure results are something we can process...should only have a
      # problem if simplib::passgen::list changes and this software was not
      # updated
      unless valid_password_list?(list)
        err_msg = 'Invalid result returned from simplib::passgen::list:' +
          "\n\n#{list}"

        raise Simp::Cli::ProcessingError.new(err_msg)
      end
    ensure
      FileUtils.remove_entry_secure(tmpdir)
    end

    list
  end

  def valid_password_list?(list)
    valid = true
    unless list.empty?
      if list.key?('keys')
        list['keys'].each do |name, info|
          unless valid_password_info?(info)
            valid = false
            break
          end
        end
      else
        valid = false
      end
    end

    valid
  end

  # Validate minimum required password info
  #
  # Looking for a Hash with the following minimum structure
  # {
  #   'value'    => { 'password' => String },
  #   'metadata' => { 'history' => Array }
  # }
  #
  def valid_password_info?(password_info)
    ( password_info.key?('value') &&
      password_info['value'].key?('password') &&
      password_info['value']['password'].is_a?(String) &&
      password_info.key?('metadata') &&
      password_info['metadata'].key?('history') &&
      password_info['metadata']['history'].is_a?(Array)
    )
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
