require 'simp/cli/commands/command'
require 'simp/cli/kv/defaults'
require 'simp/cli/kv/list_retriever'
require 'simp/cli/kv/reporting'

class Simp::Cli::Commands::Kv::List < Simp::Cli::Commands::Command

  include Simp::Cli::Kv::Reporting

  DEFAULT_BRIEF = true # whether to limit key info listed to key names

  def initialize
    @opts = {
      :backend => Simp::Cli::Kv::DEFAULT_SIMPKV_BACKEND,
      :brief   => DEFAULT_BRIEF,
      :env     => Simp::Cli::Kv::DEFAULT_PUPPET_ENVIRONMENT,
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

  # @return [String] description of command
  def self.description
    'List the contents of a folder in a simpkv backend'
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

    retriever = Simp::Cli::Kv::ListRetriever.new(@opts[:env], @opts[:backend])

    results = {}
    errors = []
    @opts[:folders].each do |folder|
      # space at end tells logger to omit <CR>
      logger.notice("Processing #{entity_description(folder, @opts)}... ")
      begin
        Simp::Cli::Utils::show_wait_spinner {
          results[folder] = retriever.list(folder, @opts[:global])
        }
        logger.notice('done.')
      rescue Exception => e
        logger.notice('done.')
        errors << "'#{folder}': #{e}"
      end
    end

    logger.notice

    unless results.empty?  # only empty if all retrievals failed!
      final_results = filter_results(results, @opts[:brief])
      report_results('list', final_results, @opts[:outfile])
    end

    unless errors.empty?
      err_msg = "Failed to retrieve list for #{errors.length} out of "\
        "#{@opts[:folders].length} folders:\n  #{errors.join("\n  ")}"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end

  #####################################################
  # Custom methods
  #####################################################

  # @return Filtered results
  #
  # @param results Results hash in which each key is a folder name
  #   and its value is the full listing of that folder
  # @param brief Whether to only list key name in lieu of full info
  #
  def filter_results(results, brief)
    final_results = {}
    if brief
      results.each do |folder,list_hash|
        final_results[folder] = {
          'keys'    => list_hash['keys'].keys.sort,
          'folders' => list_hash['folders']
        }
      end
    else
      final_results = results
    end

    final_results
  end

  # Parse command-line options for this simp command
  # @param args [Array<String>] ARGV-style args array
  def parse_command_line(args)
    ###############################################################
    # NOTE TO MAINTAINERS: The help message has been explicitly
    # formatted to fit within an 80-character-wide console window.
    ###############################################################

    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp kv list [options]'
      opts.separator <<~HELP_MSG

        #{self.class.description}

        This command lists the contents of one or more folders in a simpkv backend
        (key/value store).  It lists key names/info and sub-folders for the each
        specified folder, but does **not** recurse into sub-folders for a full tree
        listing.

        USAGE:
          simp kv list -h
          simp kv list FOLDER[,FOLDER2,...] [-e ENV] [--[no]-global] \\
            [-b BACKEND] [-o OUTFILE] [--[no-]brief] [-v|-q]

        EXAMPLES:
          # List key names and sub-folders in '/production/app1/' and
          # '/production/app2/groupY/' in 'default' backend, using simpkv config
          # from 'production' Puppet environment
          simp kv list app1,app2/groupY

          # List key info (values and metadata) and sub-folders in '/dev/app1/' in
          # 'customA' backend, using simpkv config from 'dev' Puppet environment
          simp kv list /dev/app1 -e dev -b customA --no-brief

          # List key names and sub-folders in '/app1/' global folder in 'default'
          # backend, using simpkv config from 'production' Puppet environment
          simp kv list /app1 --global

          # List key names and sub-folders in 'default' backend's root folder,
          # using simpkv config from 'production' Puppet environment
          simp kv list / --global

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

      default = @opts[:brief] ? 'enabled' : 'disabled'
      opts.on('--[no-]brief',
              'When enabled, reported key info is',
              'restricted to the key name.',
              "Defaults to #{default}.") do |brief|
        @opts[:brief] = brief
      end

      opts.on('-e', '--environment ENV',
              'Puppet environment for the folders and',
              'backend configuration. Specifies the simpkv',
              'top-level folder in which to find the',
              'folders, and where to find backend',
              'configuration. When --global is set, ENV',
              'is simply used to determine backend',
              'configuration.',
              "Defaults to '#{@opts[:env]}'.") do |env|
        @opts[:env] = env
      end

      opts.on('--[no-]global',
              'Indicates whether the folders are global',
              '(i.e., is not stored within a simpkv folder',
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
        err_msg = 'Folders to list are missing from command line'
        raise Simp::Cli::ProcessingError, err_msg
      else
        @opts[:folders] = remaining_args[0].split(',')
      end
    end
  end
end
