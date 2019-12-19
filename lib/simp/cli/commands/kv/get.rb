require 'simp/cli/commands/command'
require 'simp/cli/kv/defaults'
require 'simp/cli/kv/key_retriever'
require 'simp/cli/kv/reporting'

class Simp::Cli::Commands::Kv::Get < Simp::Cli::Commands::Command

  include Simp::Cli::Kv::Reporting

  # @return [String] description of command
  def self.description
    'Retrieve values and metadata for keys in a libkv backend'
  end

  def initialize
    @opts = {
      :env     => Simp::Cli::Kv::DEFAULT_PUPPET_ENVIRONMENT,
      :backend => Simp::Cli::Kv::DEFAULT_LIBKV_BACKEND,
      :global  => Simp::Cli::Kv::DEFAULT_GLOBAL_KEY,
      :outfile => nil,
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

    retriever = Simp::Cli::Kv::KeyRetriever.new(@opts[:env], @opts[:backend])

    results = {}
    errors = []
    @opts[:keys].each do |key|
      # space at end tells logger to omit <CR>
      logger.notice("Processing #{entity_description(key, @opts)}... ")
      begin
        Simp::Cli::Utils::show_wait_spinner {
          results[key] = retriever.get(key, @opts[:global])
        }
        logger.notice('done.')
      rescue Exception => e
        logger.notice('done.')
        errors << "'#{key}': #{e}"
      end
    end

    logger.notice

    unless results.empty?  # only empty if all retrievals failed!
      report_results('key info', results, @opts[:outfile])
    end

    unless errors.empty?
      err_msg = "Failed to retrieve key info for #{errors.length} out of "\
        "#{@opts[:keys].length} keys:\n  #{errors.join("\n  ")}"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end

  #####################################################
  # Custom methods
  #####################################################

  # Parse command-line options for this simp command
  # @param args [Array<String>] ARGV-style args array
  def parse_command_line(args)
    ###############################################################
    # NOTE TO MAINTAINERS: The help message has been explicitly
    # formatted to fit within an 80-character-wide console window.
    ###############################################################

    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp kv get [options]'
      opts.separator <<~HELP_MSG

        #{self.class.description}

        This command retrieves the value and metadata for one or more keys in a libkv
        backend (key/value store).

        USAGE:
          simp kv get -h
          simp kv get KEY[,KEY2,...] [-e ENV] [--[no]-global] [-b BACKEND] \\
            [-o OUTFILE] [-v|-q]

        EXAMPLES:
          # Print info for '/production/keyD' and '/production/app2/groupY/keyC' stored
          # in 'default' backend, using libkv config from 'production' Puppet environment
          simp kv get keyD,app2/groupY/keyC

          # Write to file info for '/dev/app1/' stored in 'customA' backend, using libkv
          # config from 'dev' Puppet environment
          simp kv get app1 -e dev -b customA -o app1.json

          # Print info for '/global_keyR' global key stored in 'default' backend, using
          # libkv config from 'production' Puppet environment
          simp kv get global_keyR --global

          # Print info '/app1/global_keyQ' global key stored in 'default' backend, using
          # libkv config from 'production' Puppet environment
          simp kv get app1/global_keyQ --global

        OPTIONS:
      HELP_MSG

      opts.on('-b', '--backend BACKEND',
              'Name of the libkv backend to use for the',
              'operation. When libkv::options::backends',
              'exists in hieradata, must be a key in that',
              "Hash. Otherwise, must be 'default'.",
              "Defaults to '#{@opts[:backend]}'.") do |backend|
        @opts[:backend] = backend
      end

      opts.on('-e', '--environment ENV',
              'Puppet environment for the keys and backend',
              'configuration. Specifies the libkv top-',
              'level folder in which to find the keys,',
              'and where to find backend configuration.',
              'When --global is set, ENV is simply used to',
              'determine backend configuration.',
              "Defaults to '#{@opts[:env]}'.") do |env|
        @opts[:env] = env
      end

      opts.on('--[no-]global',
              'Indicates whether the keys are global',
              '(i.e., is not stored within a libkv folder',
              'for a Puppet environment).',
              "Defaults to #{@opts[:global]}." ) do |global|
        @opts[:global] = global
      end

      opts.on('-o', '--outfile OUTFILE',
              'Output file to write the JSON result of the',
              'retrieval operation.  When absent the',
              'result will be sent to the console.',
              'See KEY INFO FORMAT below.' ) do |outfile|
        @opts[:outfile] = outfile
      end

      add_logging_command_options(opts, @opts)

      opts.separator ''
      opts.on('-h', '--help', 'Print this message') do
        puts opts
        @help_requested = true
      end

      opts.separator ''
      opts.separator Simp::Cli::Kv::KEY_INFO_HELP
    end

    remaining_args = opt_parser.parse(args)

    unless @help_requested
      if remaining_args.empty?
        err_msg = 'Keys to retrieve are missing from command line'
        raise Simp::Cli::ProcessingError, err_msg
      else
        @opts[:keys] = remaining_args[0].split(',')
      end
    end
  end
end
