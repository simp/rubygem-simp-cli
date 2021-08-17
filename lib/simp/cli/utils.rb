require 'simp/cli/errors'
require 'highline'
require 'highline/import'

HighLine.colorize_strings

module Simp; end
class Simp::Cli; end

module Simp::Cli::Utils

  ###################################################################
  # Let's be DRY.  Before adding methods to this file, first see if
  # Simp::Cli::***::Utils has what you need and, if so, move that
  # common functionality here!
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
      Simp::Cli::Utils.load_custom_facts

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
        :version                    => %x{puppet --version}.split(/\n/).last,
        :is_pe                      => Simp::Cli::Utils.is_pe?
      }
    end

    def get_config(environment='production', section='server')
      # Get the server section by default in case things are overridden from
      # main or don't match the agent settings

      return %x{puppet config print --environment=#{environment} --section=#{section}}.lines
    end
  end

  # Try to determine if we are on a PE server in as many ways as possible
  #
  # @return [Boolean]
  #   `true` if PE detected, `false` otherwise
  def is_pe?
    require 'facter'

    # From cheapest to most expensive
    return Facter.value('is_pe') if Facter.value('is_pe')

    return true if (@system_puppet_info && @system_puppet_info[:puppet_group] == 'pe-puppet') ||
      Facter.value('pe_build') ||
      File.exist?('/etc/puppetlabs/enterprise') ||
      File.exist?('/opt/puppetlabs/server/pe_build') ||
      File.exist?('/opt/puppetlabs/server/pe_version') ||
      File.exist?('/opt/puppetlabs/server/data/environments/enterprise')

    begin
      return true if Etc.getpwnam('pe-puppet')
    rescue
    end

    return false
  end

  def puppet_info(environment = 'production')
    unless @@puppet_info.key?(environment)
      @@puppet_info[environment] = PuppetInfo.new(environment)
    end

    return @@puppet_info[environment].system_puppet_info
  end

  # Generate a random password
  #
  # When validate is true, will keep regenerating the password until it passes
  # libpwquality/cracklib validation or the timeout is reached.
  #
  # This code is nearly identical to simplib::gen_random_password, which is
  # used in simplib::passgen.  The differences are the following additions:
  #
  # - Validation against a system password validator (pwscore from libpwquality
  #   or cracklib-check from cracklib) and password generation retry to get a
  #   password that passes the validation.
  # - Default complexity of 1, in order to generate user passwords that will
  #   pass validation on a SIMP server.
  # - Special treatment of the beginning and ending characters: Forced to be
  #   alphanumeric when complex_only is false (historical reasons?).
  #
  # @param length Length of the new password.
  #
  # @param complexity Specifies the types of characters to be used in the
  #   password
  #   * `0` => Use only Alphanumeric characters (safest)
  #   * `1` => Use Alphanumeric characters and reasonably safe symbols
  #   * `2` => Use any printable ASCII characters
  #   * Defaults to 1 so that generated password has some special characters.
  #
  # @param complex_only Use only the characters explicitly added by the
  #   complexity rules
  #
  # @param timeout_seconds Maximum time allotted to generate
  #   the password; a value of 0 disables the timeout
  #
  # @param validate Whether to regenerate the password if it fails
  #   libpwquality/cracklib validation.
  #
  #   WARNING:  Be sure to set this to false if `length` is less than
  #   the minimum required length for a user password.  Othewise, this
  #   will necessarily fail!
  #
  # @return [String] Generated password
  #
  # @raise Simp::Cli::PasswordError if fails to generate the password within
  #   the specified time.
  #
  def generate_password(length = DEFAULT_PASSWORD_LENGTH, complexity = 1,
      complex_only = false, timeout_seconds = 10, validate = true )

    require 'timeout'

    default_charlist = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    specific_charlist = nil
    case complexity
      when 1
        specific_charlist = ['@','%','-','_','+','=','~']
      when 2
        specific_charlist = (' '..'/').to_a + ('['..'`').to_a + ('{'..'~').to_a
      else
    end

    unless specific_charlist.nil?
      if complex_only == true
        charlists = [ specific_charlist ]
      else
        charlists = [ default_charlist, specific_charlist ]
      end

    else
      charlists = [ default_charlist ]
    end

    password = ''
    begin
      Timeout::timeout(timeout_seconds) do
        begin
          index = 0
          Integer(length).times do |i|
            password += charlists[index][rand(charlists[index].length-1)]
            index += 1
            index = 0 if index == charlists.length
          end

          unless complex_only || specific_charlist.nil?
            # Ensure that the password does not start or end with a special
            # character.
            # (Beginning char will always be alphanumeric in current
            # implementation above, but leaving the check in place in case
            # the implementation changes.)
            if specific_charlist.include?(password[0].chr)
              password[0] = default_charlist[rand(default_charlist.length-1)]
            end

            if specific_charlist.include?(password[password.length-1].chr)
              password[-1] = default_charlist[rand(default_charlist.length-1)]
            end
          end

          validate_password(password) if validate
        rescue Simp::Cli::PasswordError
          # password failed validation, so re-generate
          password = ''
          retry
        end
      end
    rescue Timeout::Error
      err_msg = 'Failed to generate password in allotted time'
      raise Simp::Cli::PasswordError.new(err_msg)
    end

    password
  end

  # Add custom facts to the Facter search path and then reload the facts
  #
  # This can be called as many times as necessary and will re-load the facts
  # each time with the new path.
  #
  # @param module_paths [Array[String]]
  #   Paths to search for custom facts
  # @param add_to_env [Boolean]
  #   Whether to add the custom fact paths to the FACTERLIB environment
  #   variable, in addition, so that the facts available to any spawned
  #   processes that use FACTERLIB, (e.g. `puppet apply`)
  def load_custom_facts(module_paths=[], add_to_env = false)
    require 'puppet'
    require 'facter'

    # Missing directories do not matter since they will be skipped
    default_module_paths = [
      Simp::Cli::PE_ENVIRONMENT_PATH,
      Simp::Cli::SIMP_MODULES_INSTALL_PATH
    ].map{|x| File.absolute_path(x)}

    fact_paths = []
    Facter.clear # Facter.loadfacts won't reload without this

    # First match wins, so load all passed through paths first
    (Array(module_paths) + default_module_paths).uniq.each do |dir|
      next unless File.directory?(dir)
      Find.find(dir) do |mod_path|
        Find.prune unless File.directory?(mod_path)
        if mod_path.end_with?('/lib/facter')
          Facter.search(mod_path)
          fact_paths << mod_path
        end
      end
    end

    # Called to get all of the facts that are included inside of core Facter
    # for Puppet
    Puppet.initialize_facts if Puppet.respond_to?(:initialize_facts)

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

  # Display an ASCII, spinning progress spinner for the action in a block
  # and return the result of that block
  # Example,
  #    result = show_wait_spinner {
  #      system('createrepo -q -p --update .')
  #    }
  #
  # Modification of
  # http://stackoverflow.com/questions/10262235/printing-an-ascii-spinning-cursor-in-the-console
  #
  def show_wait_spinner(frames_per_second=5)
    chars = %w[| / - \\]
    delay = 1.0/frames_per_second
    iter = 0
    spinner = Thread.new do
      while iter do  # Keep spinning until told otherwise
        print chars[(iter+=1) % chars.length]
        sleep delay
        print "\b"
      end
    end
    yield
  ensure
    iter = false   # Tell the thread to exit (even if the yield raises),
    spinner.join   # and wait for it to do so.
    print " "
  end

  # Returns a timestamp string of the form
  #   YYYY-MM-DD HH:MM:SS
  #   2019-06-05 11:04:30
  #
  # where HH is 00-23
  #
  # NOTE:  This is the standard timestamp to be used in logs
  #
  def timestamp(time = Time.now)
    time.strftime('%F %T')
  end

  # Returns a timestamp string of the form
  #   YYYYMMDDTHHMMSS
  #   20190605T110430
  #
  # where HH is 00-23
  #
  # NOTE:  This is the standard timestamp to be used in the names of
  #        log files, backup files and backup directories.
  #
  def timestamp_compact(time = Time.now)
    time.strftime('%Y%m%dT%H%M%S')
  end

  def default_simp_env_config
    default_strategy = :skeleton
    {
      types: {
        puppet: {
          enabled: true,
          strategy: default_strategy, # :skeleton, :copy (:link == noop)
          puppetfile_generate: false,
          puppetfile_install: false,
          backend: :directory,
          environmentpath: Simp::Cli::Utils.puppet_info[:config]['environmentpath'],
          skeleton_path: '/usr/share/simp/environment-skeleton/puppet',
          module_repos_path: '/usr/share/simp/git/puppet_modules',
          skeleton_modules_path: '/usr/share/simp/modules'
        },
        secondary: {
          enabled: true,
          strategy: default_strategy,   # :skeleton, :copy, :link
          backend: :directory,
          environmentpath: Simp::Cli::Utils.puppet_info[:secondary_environment_path],
          skeleton_path: '/usr/share/simp/environment-skeleton/secondary',
          rsync_skeleton_path: '/usr/share/simp/environment-skeleton/rsync',
          tftpboot_src_path: '/var/www/yum/**/images/pxeboot',
          tftpboot_dest_path: 'rsync/RedHat/Global/tftpboot/linux-install'
        },
        writable: {
          enabled: true,
          strategy: default_strategy,   # :copy, :link (:skeleton == noop)
          backend: :directory,
          environmentpath: Simp::Cli::Utils.puppet_info[:writable_environment_path]
          # skeleton_path: '/usr/share/simp/environment-skeleton/writable',  # <-- per discussions, not used
        }
      },
    }
  end

  # Prompt the user for a 'yes' or 'no' value, read it in and convert
  # to a Boolean
  #
  # @return true if the user entered 'yes' or 'y'; false if the user
  #   entered 'no' or 'n'
  #
  def yes_or_no(prompt, default_yes)
    question = "> #{prompt.bold}: "
    answer = ask(question) do |q|
      q.validate = /^y$|^n$|^yes$|^no$/i
      q.default = (default_yes ? 'yes' : 'no')
      q.responses[:not_valid] = "Invalid response. Please enter 'yes' or 'no'".red
      q.responses[:ask_on_error] = :question
      q
    end
    result = (answer.downcase[0] == 'y')
  end

  # @return whether a systemd service is running
  # @param name Name of the systemd service
  def systemctl_running?(name)
    system("/usr/bin/systemctl status #{name} > /dev/null 2>&1")
    $?.nil? ? false : ($?.exitstatus == 0)
  end
end
