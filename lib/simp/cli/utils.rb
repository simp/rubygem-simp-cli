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

    def get_config
      return %x{puppet config print}.lines
    end
  end

  def puppet_info
    @@puppet_info ||= PuppetInfo.new

    return @@puppet_info.system_puppet_info
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
    if result != "OK"
      # detailed message already includes 'Invalid Password'
      raise Simp::Cli::PasswordError, "Invalid Password: #{result}"
    end
  end
end
