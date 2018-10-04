require 'simp/cli/errors'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Utils

  ###################################################################
  # Let's be DRY.  Before adding methods to this file, first see if
  # Simp::Cli::Utils::Config has what you need and, if so, move
  # that common functionality here!
  ###################################################################

  module_function

  DEFAULT_PASSWORD_LENGTH = 32

  @@puppet_info = nil
  @@simp_env_datadir = nil

  class PuppetInfo
    attr_reader :system_puppet_info

    def initialize
      config = get_config

      # Kill the comments and blanks if any exists
      config_hash = Hash.new
      config.each do |line|
        next if line =~ /^\s*(#.*)?$/

        param,value = line.split('=')
        param.strip!
        value.strip!

        value = nil if value.empty?
        config_hash[param] = value
      end

      # Check for Puppet 4 paths first
      if config_hash['codedir']
        environment_path = File.join(config_hash['codedir'], 'environments')
      else
        environment_path = File.join(config_hash['confdir'], 'environments')
      end

      @system_puppet_info = {
        :config => config_hash,
        :environment_path => environment_path,
        :simp_environment_path => File.join(environment_path, 'simp'),
        :fake_ca_path => '/var/simp/environments/simp/FakeCA',
        :puppet_group => config_hash['group']
      }
    end

    def get_config(section='master')
      # Get the master section by default in case things are overridden from
      # main or don't match the agent settings

      return %x{puppet config print --section=#{section}}.lines
    end
  end

  def puppet_info
    @@puppet_info ||= PuppetInfo.new

    return @@puppet_info.system_puppet_info
  end

  # Returns the (discovered) 'simp' environment data directory
  # Raises Simp::Cli::ProcessingError if a 'simp' environment data
  # directory for a stock SIMP system does not exist
  def simp_env_datadir
    unless @@simp_env_datadir.nil?
      return @@simp_env_datadir
    end

    @@simp_env_datadir = get_stock_simp_env_datadir

    if @@simp_env_datadir.nil?
      err_msg = 'simp environment hieradata directory cannot be determined.'
      raise Simp::Cli::ProcessingError.new(err_msg)
    end
    @@simp_env_datadir
  end

  # Returns the 'simp' environment data directory, when one of the
  # standard SIMP installations has been detected.
  # Returns nil otherwise.
  #
  # SIMP-6.0.0 through SIMP-6.2.0 use a global Hiera 3
  # hiera.yaml file that is configured to find environment hieradata
  # in .../environments/simp/hieradata.
  #
  # Beginning with SIMP-6.3.0, SIMP uses an environment-specific
  # Hiera 5 hiera.yaml file that is configured to find environment
  # hieradata in .../environments/simp/data.
  def get_stock_simp_env_datadir
    stock_simp_env_datadir = nil
    # Check (weakly) for stock SIMP configurations.
    env_hiera5_file = File.join(puppet_info[:simp_environment_path], 'hiera.yaml')
    env_hiera5_dir = File.join(puppet_info[:simp_environment_path], 'data')
    env_hiera3_dir = File.join(puppet_info[:simp_environment_path], 'hieradata')
    if File.exist?(env_hiera5_file)
      # Using environment-specific Hiera 5 configuration
      if Dir.exist?(env_hiera5_dir)
        # The data directory SIMP uses for Hiera 5 is in place, so we are
        # ASSUMING this is a stock SIMP configuration.
        stock_simp_env_datadir = env_hiera5_dir
      end
    elsif Dir.exist?(env_hiera3_dir)
      stock_simp_env_datadir = env_hiera3_dir
    end

    stock_simp_env_datadir
  end

  def generate_password(length = DEFAULT_PASSWORD_LENGTH )
    password = ''
    begin
      special_chars = ['#','%','&','*','+','-','.',':','@']
      symbols = ('0'..'9').to_a + ('A'..'Z').to_a + ('a'..'z').to_a
      Integer(length).times { |i| password += (symbols + special_chars)[rand((symbols.length-1 + special_chars.length-1))] }
      # Ensure that the password does not start or end with a special
      # character.
      special_chars.include?(password[0].chr) and password[0] = symbols[rand(symbols.length-1)]
      special_chars.include?(password[password.length-1].chr) and password[password.length-1] = symbols[rand(symbols.length-1)]

      # make sure password passes validation
      validate_password(password)
    rescue Simp::Cli::PasswordError
      # password failed validation, so re-generate
      password = ''
      retry
    end
    password
  end

  # Validates a password using available system tools
  # Raises Simp::Cli::PasswordError upon validation failure
  def validate_password(password)
    if File.exist?('/usr/bin/pwscore')
      # pwscore uses libpwquality, which is more rigorous than
      # cracklib, alone, in a configured SIMP system
      validate_password_with_pwscore(password)
    elsif password.length < 8
      # 8 is the 'industry standard' minimum password length
      raise Simp::Cli::PasswordError, 'Invalid Password: Password must be at least 8 characters long'
    else
      validate_password_with_cracklib(password)
    end
  end

  # Validates a password using libpwquality's validator, pwscore
  # Raises Simp::Cli::PasswordError upon validation failure
  def validate_password_with_pwscore(password)
    require 'shellwords'
    result = `echo #{Shellwords.escape(password)} | /usr/bin/pwscore 2>&1`.strip
    status = $?
    unless (!status.nil? and status.success?)
      # detailed message is in the second line
      raise Simp::Cli::PasswordError, "Invalid Password: #{result.split("\n")[1]}"
    end
  end

  # Validates a password using cracklib's validator, cracklib-check
  # Raises Simp::Cli::PasswordError upon validation failure
  def validate_password_with_cracklib(password)
    require 'shellwords'
    # message is <password>: OK or <password>: <validation failure description>
    result = `echo #{Shellwords.escape(password)} | cracklib-check`.split(':').last.strip
    if result != 'OK'
      # detailed message already includes 'Invalid Password'
      raise Simp::Cli::PasswordError, "Invalid Password: #{result}"
    end
  end
end
