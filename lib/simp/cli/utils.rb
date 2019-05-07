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
  REGEXP_UNIXPATH = %r{\A(?:\/[\w-]*\/?)+\z}

  # According to https://puppet.com/docs/puppet/5.5/environments_creating.html,
  # This should be \A[a-z0-9_]+\Z.  However, there is currently a bug that prevents
  # all-numeric environment names:
  #
  #   https://tickets.puppetlabs.com/browse/PUP-8289
  #
  REGEXP_PUPPET_ENV_NAME = %r{\A[a-z][a-z0-9_]*\Z}

  @@puppet_info = {}

  class PuppetInfo
    attr_reader :system_puppet_info

    def initialize(environment)
      config = get_config(environment)

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

      puppet_environment_path    = config_hash['environmentpath']
      secondary_environment_path = '/var/simp/environments'
      writable_environment_path  = File.expand_path('../simp/environments', config_hash['statedir'])

      @system_puppet_info = {
        :config                     => config_hash,
        :environment_path           => puppet_environment_path,
        :secondary_environment_path => secondary_environment_path,
        :writable_environment_path  => writable_environment_path,
        :puppet_group               => config_hash['group'],
        :version                    => %x{puppet --version}.split(/\n/).last
      }
    end

    def get_config(environment='production', section='master')
      # Get the master section by default in case things are overridden from
      # main or don't match the agent settings

      return %x{puppet config print --environment=#{environment} --section=#{section}}.lines
    end
  end

  def puppet_info(environment = 'production')
    unless @@puppet_info.key?(environment)
      @@puppet_info[environment] = PuppetInfo.new(environment)
    end

    return @@puppet_info[environment].system_puppet_info
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

  # Add custom facts to the Facter search path and then reload the facts
  #
  # +module_paths+: Array of module paths in which to find custom facts
  # +add_to_env+:   Whether to add the custom fact paths to the FACTERLIB
  #   environment variable, in addition, so that the facts available to
  #   any spawned processes that use FACTERLIB, (e.g. `puppet apply`)
  def load_custom_facts(module_paths, add_to_env = false)
    fact_paths = []
    Facter.clear  # Facter.loadfacts won't reload without this
    module_paths.each do |dir|
      next unless File.directory?(dir)
      Find.find(dir) do |mod_path|
        fact_path = File.expand_path('lib/facter', mod_path)
        if File.directory?(fact_path)
          Facter.search(fact_path)
          fact_paths << fact_path
        end
        Find.prune unless mod_path == dir
      end
    end
    Facter.loadfacts

    if add_to_env
      fact_paths << ENV['FACTERLIB'] unless ENV['FACTERLIB'].nil? || ENV['FACTERLIB'].empty?
      ENV['FACTERLIB'] = fact_paths.join(':')
    end

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
