require 'simp/cli/commands/command'
require 'simp/cli/kv/defaults'
require 'simp/cli/kv/key_storer'
require 'simp/cli/kv/info_validator'
require 'simp/cli/kv/reporting'
require 'simp/cli/utils'
require 'json'

class Simp::Cli::Commands::Kv::Put < Simp::Cli::Commands::Command

  include Simp::Cli::Kv::Reporting

  def initialize
    @opts = {
      :env     => Simp::Cli::Kv::DEFAULT_PUPPET_ENVIRONMENT,
      :backend => Simp::Cli::Kv::DEFAULT_SIMPKV_BACKEND,
      :global  => Simp::Cli::Kv::DEFAULT_GLOBAL_KEY,
      :force   => Simp::Cli::Kv::DEFAULT_FORCE,
      :verbose => 0  # Verbosity of console output:
      #                -1 = ERROR  and above
      #                 0 = NOTICE and above
      #                 1 = INFO   and above
      #                 2 = DEBUG  and above
      #                 3 = TRACE  and above  (developer debug)
    }
  end

  #####################################################
  # Simp::Cli::Commands::Command API methods
  #####################################################

  # @return [String] description of command
  def self.description
    'Set the value and metadata for keys in a simpkv backend'
  end

  # Run the command's `--help` action
  def help
    parse_command_line(['--help'])
  end

  # Run command logic
  # @param args [Array<String>] ARGV-style args array
  def run(args)
    parse_command_line(args)
    return if @help_requested

    # set verbosity threshold for console logging
    set_up_global_logger(@opts[:verbose])

    extract_key_info

    storer = Simp::Cli::Kv::KeyStorer.new(@opts[:env], @opts[:backend])

    errors = []
    @opts[:keys].each do |key,info|
      set = @opts[:force]
      unless @opts[:force]
        prompt = "Are you sure you want to set key '#{key}'?".bold
        set = Simp::Cli::Utils::yes_or_no(prompt, false)
      end

      if set
        # space at end tells logger to omit <CR>
        logger.notice("Processing #{entity_description(key, @opts)}... ")
        begin
          Simp::Cli::Utils::show_wait_spinner {
            storer.put(key, info['value'], info['metadata'],
              binary_value?(info), @opts[:global])
          }
          logger.notice('done.')
          logger.notice("  Set '#{key}'")
        rescue Exception => e
          logger.notice('done.')
          logger.notice("  Skipped '#{key}'")
          errors << "'#{key}': #{e}"
        end
      else
        logger.notice("Skipped #{entity_description(key, @opts)}")
      end

      logger.notice
    end

    unless errors.empty?
      err_msg = "Failed to set #{errors.length} out of "\
        "#{@opts[:keys].length} keys:\n  #{errors.join("\n  ")}"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end

  #####################################################
  # Custom methods
  #####################################################
  #
  def binary_value?(key_info)
    (
      key_info.key?('encoding') &&
      key_info.key?('original_encoding') &&
      key_info['value'].is_a?(String)
    )
  end

  # extracts the value and metadata for each key from the JSON input
  #
  # @raise Simp::Cli::ProcessingError if the JSON file cannot be read,
  #   the JSON is malformed, the JSON is missing the 'value' or
  #   'metadata' attributes or the 'metadata' attribute is not a Hash
  #
  def extract_key_info
    jsonstring = nil
    if @opts.key?(:jsonstring)
      logger.debug('Extracting key information from JSON string')
      jsonstring = @opts[:jsonstring]
    else
      begin
        logger.debug('Extracting key information from JSON file')
        jsonstring = File.read(@opts[:infile])
      rescue Exception => e
        err_msg = "Failed to read #{@opts[:infile]}: #{e}"
        raise Simp::Cli::ProcessingError, err_msg
      end
    end

    begin
      in_hash = JSON.parse(jsonstring)
    rescue JSON::JSONError => e
      # will get here if jsonstring is invalid or file cannot be read
      err_msg = "Invalid JSON: #{e}"
      raise Simp::Cli::ProcessingError, err_msg
    end

    unless in_hash.is_a?(Hash)
      raise Simp::Cli::ProcessingError, 'Malformed JSON: Not a Hash'
    end

    if in_hash.empty?
      raise Simp::Cli::ProcessingError, 'No keys specified in JSON'
    end

    in_hash.each do |key,info|
      begin
        Simp::Cli::Kv::InfoValidator::validate_key_info(key, info)
      rescue Simp::Cli::ProcessingError => e
        err_msg = "Malformed JSON: #{e}"
        raise Simp::Cli::ProcessingError, err_msg
      end
    end

    @opts[:keys] = in_hash
  end

  # Parse command-line options for this simp command
  # @param args [Array<String>] ARGV-style args array
  #
  # @raise Exception Upon any parsing failure
  #
  def parse_command_line(args)
    ###############################################################
    # NOTE TO MAINTAINERS: The help message has been explicitly
    # formatted to fit within an 80-character-wide console window.
    ###############################################################

    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp kv put [options]'
      opts.separator <<~HELP_MSG

        #{self.class.description}

        This command sets the value and metadata for one or more keys in a simpkv
        backend (key/value store) from JSON.  This will create the key entry if it
        does not already exist.

        USAGE:
          simp kv put -h
          simp kv put -i INFILE [-e ENV] [--[no]-global] [-b BACKEND]  [--[no-]force] \\
            [-v|-q]
          simp kv put --json JSONSTRING [-e ENV] [--[no]-global] [-b BACKEND] \\
            [--[no-]force] [-v|-q]

        EXAMPLES:
          # Set key info from a JSON string for '/production/keyD' in 'default'
          # backend, using simpkv config from 'production' Puppet environment
          simp kv put --json='{"keyD":{"value":10,"metadata":{"foo":"bar","baz":10}}}'

          # Set key info from a JSON file for '/production/<key name>' keys in
          # 'dev' backend, using simpkv config from 'dev' Puppet environment
          simp kv put -i keys.json -e dev

          # Set key info from a JSON file for global keys in 'default' backend without
          # confirmation prompt, using simpkv config from 'production' Puppet environment
          simp kv put -i global_keys.json --global --force

          # Set key info from a JSON string for 'app1/global_keyQ' global key in
          # 'default' backend, using simpkv config from 'production' Puppet environment
          simp kv put --global\\
            --json='{"app1/global_keyQ":{"value":{"foo":"bar"},"metadata":{}}}'

        OPTIONS:
      HELP_MSG

      opts.on('-b', '--backend BACKEND',
              'Name of the simpkv backend to use for the',
              'operation. When simpkv::options::backends',
              'exists in hieradata, must be a key in that',
              "Hash. Otherwise, must be 'default'.",
              "Defaults to '#{@opts[:backend]}'.") do |backend|
        @opts[:backend] = backend
      end

      opts.on('-e', '--environment ENV',
              'Puppet environment for the key and backend',
              'configuration. Specifies the simpkv top-',
              'level folder in which to put the key,',
              'and where to find backend configuration.',
              'When --global is set, ENV is simply used to',
              'determine backend configuration.',
              "Defaults to '#{@opts[:env]}'.") do |env|
        @opts[:env] = env
      end

      default = @opts[:force] ? 'enabled' : 'disabled'
      opts.on('--[no-]force',
              'Set keys without prompting user to',
              'confirm. When disabled, the user will be',
              'prompted to confirm the setting for each',
              "key. Defaults to #{default}.") do |force|
        @opts[:force] = force
      end

      opts.on('--[no-]global',
              'Indicates whether the key is global',
              '(i.e., is not stored within a simpkv folder',
              'for a Puppet environment).',
              "Defaults to #{@opts[:global]}." ) do |global|
        @opts[:global] = global
      end

      opts.on('-i', '--infile INFILE',
              'Input file from which to read the JSON',
              'representation of the key info to be',
              'persisted in the store. --infile and --json',
              'are mutually exclusive.',
              'See INPUT FORMAT below.' ) do |infile|
        @opts[:infile] = infile
      end

      opts.on('--json JSONSTRING',
              'JSON representation of the key info to be',
              'persisted in the store. --infile and --json',
              'are mutually exclusive.',
              'See INPUT FORMAT below.' ) do |jsonstring|
        @opts[:jsonstring] = jsonstring
      end

      add_logging_command_options(opts, @opts)

      opts.separator ''
      opts.on('-h', '--help', 'Print this message') do
        puts opts
        @help_requested = true
      end

      opts.separator ''
      opts.separator <<~INPUT_FORMAT
        INPUT FORMAT
        The input data must be specified as a Hash in JSON format.  Each Hash element
        corresponds to a key to be set, where the name of the element is the key name
        and its value is a key information Hash described in KEY INFO FORMAT below.

        Here is example JSON to set 'key1', 'key2', and 'key3' keys:

          {
            "key1": {"value":2.3849,"metadata":{"foo":{"bar":"baz"}}},
            "key2": {"value":["hello","world"],"metadata":{}},
            "key3": {"value":{"some":"hash"},"metadata":{"seq":[7,10]}}
          }

        #{Simp::Cli::Kv::KEY_INFO_HELP}
      INPUT_FORMAT
    end

    remaining_args = opt_parser.parse(args)

    unless @help_requested
      if @opts.key?(:infile) && @opts.key?(:jsonstring)
        err_msg = '--infile and --json are mutually exclusive'
        raise Simp::Cli::ProcessingError, err_msg
      end
    end
  end
end
