require 'simp/cli/errors'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Utils

  ###################################################################
  # Let's be DRY.  Before adding methods to this file, first see if
  # Simp::Cli::Config::Utils has what you need and, if so, move that
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

    def get_config(environment='production', section='master')
      # Get the master section by default in case things are overridden from
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
  # Lifted from
  # http://stackoverflow.com/questions/10262235/printing-an-ascii-spinning-cursor-in-the-console
  #
  # FIXME:  This is a duplicate of code in simp/cli/config/items/item.rb.
  # Need to share that code.
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
    yield.tap {      # After yielding to the block, save the return value
      iter = false   # Tell the thread to exit, cleaning up after itself
      spinner.join   # and wait for it to do so.
    }                # Use the block's return value as the method's
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
end
