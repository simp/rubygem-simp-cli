require 'simp/cli/commands/command'
require 'simp/cli/kv/defaults'
require 'simp/cli/kv/entity_checker'
require 'simp/cli/kv/reporting'

class Simp::Cli::Commands::Kv::Exists < Simp::Cli::Commands::Command

  include Simp::Cli::Kv::Reporting

  def initialize
    @opts = {
      :env     => Simp::Cli::Kv::DEFAULT_PUPPET_ENVIRONMENT,
      :backend => Simp::Cli::Kv::DEFAULT_SIMPKV_BACKEND,
      :global  => Simp::Cli::Kv::DEFAULT_GLOBAL_KEY,
      :verbose      => 0  # Verbosity of console output:
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
    'Check for existence of keys/folders in a simpkv backend'
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

    checker = Simp::Cli::Kv::EntityChecker.new(@opts[:env], @opts[:backend])

    results = {}
    errors = []
    mapping = { true => 'present', false => 'absent'}
    @opts[:entities].each do |entity|
      begin
        # space at end tells logger to omit <CR>
        logger.notice("Processing #{entity_description(entity, @opts)}... ")
        Simp::Cli::Utils::show_wait_spinner {
          results[entity] = mapping[checker.exists(entity, @opts[:global])]
        }
        logger.notice('done.')
      rescue Exception => e
        logger.notice('done.')
        errors << "'#{entity}': #{e}"
      end
    end

    logger.notice

    unless results.empty?  # only empty if all check operations failed!
      report_results('folder/key existence check', results, @opts[:outfile])
    end

    unless errors.empty?
      err_msg = "Failed to check existence of #{errors.length} out of "\
        "#{@opts[:entities].length} folders/keys:\n  #{errors.join("\n  ")}"
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
    #
    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp kv exists [options]'
      opts.separator <<~HELP_MSG

        #{self.class.description}

        This command checks for the existence of one or more keys/folders in a
        simpkv backend (key/value store).

        USAGE:
          simp kv exists -h
          simp kv exists ENTITY[,ENTITY2,...] [-e ENV] [--[no]-global] [-b BACKEND] \\
            [-o OUTFILE] [-v|-q]

        EXAMPLES:
          # Check if '/production/keyD' and '/production/app2/groupY/keyC' exist in
          # 'default' backend, using simpkv config from 'production' Puppet environment
          simp kv exists keyD,app2/groupY/keyC

          # Check if '/dev/app1/' exists in 'customA' backend, using simpkv config
          # from 'dev' Puppet environment
          simp kv exists app1 -e dev -b customA

          # Check if '/global_keyR' global key exists in 'default' backend, using
          # simpkv config from 'production' Puppet environment
          simp kv exists global_keyR --global

          # Check if '/app1/' global folder exists in 'default' backend, using simpkv
          # config from 'production' Puppet environment
          simp kv exists app1 --global

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
              'Puppet environment for the keys/folders and',
              'backend configuration. Specifies the simpkv',
              'top-level folder in which to find the keys/',
              'folders, and where to find backend',
              'configuration. When --global is set, ENV',
              'is simply used to determine backend',
              'configuration.',
              "Defaults to '#{@opts[:env]}'.") do |env|
        @opts[:env] = env
      end

      opts.on('--[no-]global',
              'Indicates whether the keys/folders are',
              'global (i.e., is not stored within a simpkv',
              'folder for a Puppet environment).',
              "Defaults to #{@opts[:global]}." ) do |global|
        @opts[:global] = global
      end

      opts.on('-o', '--outfile OUTFILE',
              'Output file to write the JSON result of the',
              'check operation.  When absent the result',
              'will be sent to the console.' ) do |outfile|
        @opts[:outfile] = outfile
      end

      add_logging_command_options(opts, @opts)

      opts.separator ''
      opts.on_tail('-h', '--help', 'Print this message') do
        puts opts
        @help_requested = true
      end
    end

    remaining_args = opt_parser.parse(args)

    unless @help_requested
      if remaining_args.empty?
        err_msg = 'Folders/keys to check are missing from command line'
        raise Simp::Cli::ProcessingError, err_msg
      else
        @opts[:entities] = remaining_args[0].split(',')
      end
    end
  end

end
