require 'simp/cli/utils'
require 'simp/cli/exec_utils'

require 'highline'
require 'highline/import'
require 'yaml'
require 'tmpdir'

HighLine.colorize_strings

module Simp; end
class Simp::Cli; end
module Simp::Cli::Passgen; end

module Simp::Cli::Passgen::Utils
  require 'fileutils'

  # Prompt the user for a password, read it in, confirm it and then
  # optionally validate it against libpwquality/cracklib
  #
  # @param attempts Number of times to attempt to gather the password
  #  from the user
  #
  # @param validate Whether to validate the password against
  #   libwpquality/cracklib
  #
  # @param min_length Minimum password length to enforce when validate is
  #   false
  #
  # @return password
  # @raise  Simp::Cli::ProcessingError if a valid password cannot be
  #   gathered within specified number of attempts
  #
  def self.get_password(attempts = 5, validate = true, min_length = 8)
    if (attempts == 0)
      err_msg = 'FATAL: Too many failed attempts to enter password'
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    password = ''
    question1 = "> #{'Enter password'.bold}: "
    password = ask(question1) do |q|
      q.echo = '*'
      q.validate = lambda { |answer|
        valid = nil
        if validate
          valid = self.validate_password(answer)
        else
          # Make sure the length is not too short or manifest will fail
          # to apply with a difficult-to-understand error message!
          valid =self.validate_password_length(answer, min_length)
        end
        valid
      }

      q.responses[:not_valid] = nil
      q.responses[:ask_on_error] = :question
      q
    end

    question2 = "> #{'Confirm password'.bold}: "
    confirm_password = ask(question2) do |q|
      q.echo = '*'
      q
    end

    if password != confirm_password
      $stderr.puts '  Passwords do not match! Please try again.'.red.bold

      # start all over
      password = get_password(attempts - 1, validate, min_length)
    end

    password
  end

  # Validate the password using libpwquality/cracklib validators
  # installed on the local system.
  #
  # TODO  What about validating length, complexity, complex_only?
  #
  # @return whether password validated
  #
  def self.validate_password(password)
    begin
      Simp::Cli::Utils::validate_password(password)
      return true
    rescue Simp::Cli::PasswordError => e
      $stderr.puts "  #{e.message}.".red.bold
      return false
    end
  end

  # Validate the password length is no smaller than the minimum required length
  # @param password Password to validate
  # @param min_length Minimum password length
  #
  # @return whether password length is sufficient
  #
  def self.validate_password_length(password, min_length)
    if password.length < min_length
      msg = "  Password too short. Must be at least #{min_length} "\
            'characters long.'

      $stderr.puts msg.red.bold
      return false
    else
      return true
    end
  end

  # Prompt the user for a 'yes' or 'no' value, read it in and convert
  # to a Boolean
  #
  # @return true if the user entered 'yes' or 'y'; false if the user
  #   entered 'no' or 'n'
  #
  def self.yes_or_no(prompt, default_yes)
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

  # Apply a Puppet manifest with simplib::passgen commands in an environment
  #
  # The 'puppet apply' is customized for simplib::passgen functions
  # * The apply sets Puppet's vardir setting explicitly to that of the puppet
  #   master.
  #   - vardir is used in simplib::passgen functions to determine the
  #     location of password files.
  #   - vardir defaults to the puppet agent's setting (a different value)
  #     otherwise.
  # * The apply is wrapped in 'sg  <puppet group>' to ensure any files or
  #   directories created by a simplib::passgen function are still accessible
  #   by the puppetserver.  This group setting, alone, is insufficient for
  #   legacy passgen files, but works when used in conjunction with a
  #   legacy-passgen-specific 'user' setting in manifests that create/update
  #   passwords.
  #
  # LIMITATION:  This 'puppet apply' operation has ONLY been tested for
  # manifests containing simplib::passgen functions and applied as the root
  # user.
  #
  # @param manifest Contents of the manifest to be applied
  # @param opts Options
  #  * :env   - Puppet environment to which manifest will be applied.
  #             Defaults to 'production' when unspecified.
  #  * :fail  - Whether to raise an exception upon manifest failure.
  #             Defaults to true when unspecified
  #  * :title - Brief description of operation. Used in the exception
  #             message when apply fails and :fail is true.
  #             Defaults to 'puppet apply' when unspecified.
  #
  # @param logger Optional Simp::Cli::Logging::Logger object. When not
  #    set, logging is suppressed.
  #
  # @raise Simp::Cli::ProcessingError if manifest apply fails and :fail is true
  #
  # TODO Replace with Puppet PAL and rework manifests to return retrieved
  #   values, when we drop support for Puppet 5
  #
  def self.apply_manifest(manifest, opts = { :env => 'production',
      :fail => false, :title => 'puppet apply'}, logger = nil)

    options = opts.dup
    options[:env]   = 'production'   unless options.key?(:env)
    options[:fail]  = true           unless options.key?(:fail)
    options[:title] = 'puppet apply' unless options.key?(:title)

    puppet_info = Simp::Cli::Utils.puppet_info(options[:env])

    result = nil
    cmd = nil
    Dir.mktmpdir( File.basename( __FILE__ ) ) do |dir|
      logger.debug("Creating manifest file for #{options[:title]} with" +
        " content:\n#{manifest}") if logger

      manifest_file = File.join(dir, 'passgen.pp')
      File.open(manifest_file, 'w') { |file| file.puts manifest }
      puppet_apply = [
        'puppet apply',
        '--color=false',
        "--environment=#{options[:env]}",
        "--vardir=#{puppet_info[:config]['vardir']}",
        manifest_file
      ].join(' ')

      # We need to defer handling of error logging to the caller, so don't pass
      # logger into run_command().  Since we are not using the logger in
      # run_command(), we will have to duplicate the command debug logging here.
      cmd = "sg #{puppet_info[:config]['group']} -c '#{puppet_apply}'"
      logger.debug( "Executing: #{cmd}" ) if logger
      result = Simp::Cli::ExecUtils.run_command(cmd)
    end

    if logger
      logger.debug(">>> stdout:\n#{result[:stdout]}")
      logger.debug(">>> stderr:\n#{result[:stderr]}")
    end

    if !result[:status] && options[:fail]
      err_msg = [
        "#{options[:title]} failed:",
        ">>> Command: #{cmd}",
        '>>> Manifest:',
        manifest,
        '>>> stderr:',
        result[:stderr]
      ].join("\n")
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    result
  end


  # Load YAML from a file and return the resulting Hash
  #
  # @param file Name of file to load
  # @param id identifier to print in messages
  # @param logger Optional Simp::Cli::Logging::Logger object. When not
  #    set, logging is suppressed.
  #
  # @return Hash representation of YAML
  # @raise Simp::Cli::ProcessingError if file cannot be read or parsed
  #
  def self.load_yaml(file, id, logger = nil)
    yaml = nil
    content = nil
    begin
      logger.debug("Loading #{id} YAML from file") if logger
      content = File.read(file)
      logger.debug("Content:\n#{content}") if logger
      yaml = YAML.load(content)
    rescue Exception => e
      err_msg = "Failed to load #{id} YAML:\n"
      err_msg += "<<< YAML Content:\n#{content}\n"  unless content.nil?
      err_msg += "<<< Error: #{e}"
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    yaml
  end

end
