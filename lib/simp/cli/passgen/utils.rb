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

end
