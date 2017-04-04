module Utils

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

  def yes_or_no(prompt, default_yes)
    print prompt + (default_yes ? ' [Y|n]: ' : ' [y|N]: ')
    case STDIN.gets.strip
    when /^(y|Y)/
      true
    when /^(n|N)/
      false
    when /^\s*$/
      default_yes
    else
      yes_or_no(prompt, default_yes)
    end
  end

  def get_password
    print 'Enter password: '

    system('/bin/stty', '-echo')
    password1 = STDIN.gets.strip
    system('/bin/stty', 'echo')
    puts

    print 'Re-enter password: '
    system('/bin/stty', '-echo')
    password2 = STDIN.gets.strip
    system('/bin/stty', 'echo')
    puts

    if password1 == password2
      if validate_password(password1)
        password1
      else
        get_password
      end
    else
      puts "  Passwords do not match! Please try again."
      get_password
    end
  end

  def generate_password(length = DEFAULT_PASSWORD_LENGTH, default_is_autogenerate = true)
    password = ''
    if Utils.yes_or_no('Do you want to autogenerate the password?', default_is_autogenerate )
      special_chars = ['#','%','&','*','+','-','.',':','@']
      symbols = ('0'..'9').to_a + ('A'..'Z').to_a + ('a'..'z').to_a
      Integer(length).times { |i| password += (symbols + special_chars)[rand((symbols.length-1 + special_chars.length-1))] }
      # Ensure that the password does not start or end with a special
      # character.
      special_chars.include?(password[0].chr) and password[0] = symbols[rand(symbols.length-1)]
      special_chars.include?(password[password.length-1].chr) and password[password.length-1] = symbols[rand(symbols.length-1)]
      puts "Your password is:\n#{password}"
      print 'Push [ENTER] to continue.'
      $stdout.flush
      $stdin.gets
    else
      password = Utils.get_password
    end
    password
  end

  def validate_password(password)
    require 'shellwords'

    if password.length < 8
      puts "  Invalid Password: Password must be at least 8 characters long"
      false
    else
      pass_result = `echo #{Shellwords.escape(password)} | cracklib-check`.split(':').last.strip
      if pass_result == "OK"
        true
      else
        puts "  Invalid Password: #{pass_result}"
        false
      end
    end
  end

  def get_value(default_value = '')
    case default_value
    when /\d+\.\d+\.\d+\.\d+/
      print "Enter a new IP: "
      value = STDIN.gets.strip
      while !valid_ip?(value)
        puts "INVALID! Try again..."
        print "Enter a new IP: "
        value = STDIN.gets.strip
      end
    else
      print "Enter a value: "
      value = STDIN.gets.strip
    end
    value
  end

  def valid_ip?(value)
    value.to_s =~ /^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
  end
end
