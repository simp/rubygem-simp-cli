require 'simp/cli/commands/command'
require 'simp/cli/kv/defaults'
require 'simp/cli/kv/tree_deleter'
require 'simp/cli/kv/reporting'

class Simp::Cli::Commands::Kv::Deletetree < Simp::Cli::Commands::Command

  include Simp::Cli::Kv::Reporting

  def initialize
    @opts = {
      :env      => Simp::Cli::Kv::DEFAULT_PUPPET_ENVIRONMENT,
      :backend  => Simp::Cli::Kv::DEFAULT_SIMPKV_BACKEND,
      :global   => Simp::Cli::Kv::DEFAULT_GLOBAL_KEY,
      :force    => Simp::Cli::Kv::DEFAULT_FORCE,
      :verbose  => 0  # Verbosity of console output:
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
    'Delete folders from a simpkv backend'
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

    deleter = Simp::Cli::Kv::TreeDeleter.new(@opts[:env], @opts[:backend])

    errors = []
    @opts[:folders].each do |folder|
      remove = @opts[:force]
      unless @opts[:force]
        prompt = "Are you sure you want to remove folder '#{folder}'?".bold
        remove = Simp::Cli::Utils::yes_or_no(prompt, false)
      end

      if remove
        # space at end tells logger to omit <CR>
        logger.notice("Processing #{entity_description(folder, @opts)}... ")
        begin
          Simp::Cli::Utils::show_wait_spinner {
            deleter.deletetree(folder, @opts[:global])
          }
          logger.notice('done.')
          logger.notice("  Removed '#{folder}'")
        rescue Exception => e
          logger.notice('done.')
          logger.notice("  Skipped '#{folder}'")
          errors << "'#{folder}': #{e}"
        end
      else
        logger.notice("Skipped #{entity_description(folder, @opts)}")
      end

      logger.notice
    end

    unless errors.empty?
      err_msg = "Failed to remove #{errors.length} out of "\
        "#{@opts[:folders].length} folders:\n  #{errors.join("\n  ")}"
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
      opts.banner = '== simp kv deletetree [options]'
      opts.separator <<~HELP_MSG

        #{self.class.description}

        This command deletes one or more folders from a simpkv backend (key/value store).

        USAGE:
          simp kv deletetree -h
          simp kv deletetree FOLDER[,FOLDER2,...] [-e ENV] [--[no]-global] \\
            [-b BACKEND] [--[no-]force] [-v|-q]

        EXAMPLES:
          # Delete '/production/app1/' and '/production/app2/groupY/' from 'default'
          # backend, using simpkv config from 'production' Puppet environment
          simp kv deletetree app1,app2/groupY

          # Delete '/dev/app1/' from 'customA' backend without confirmation prompt,
          # using simpkv config from 'dev' Puppet environment
          simp kv deletetree /dev/app1 -e dev -b customA --force

          # Delete '/app1/' global folder from 'default' backend, using simpkv
          # config from 'production' Puppet environment
          simp kv deletetree /app1 --global

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

      default = @opts[:force] ? 'enabled' : 'disabled'
      opts.on('--[no-]force',
              'Remove folders without prompting user to',
              'confirm. When disabled, the user will be',
              'prompted to confirm the removal for each',
              "folder. Defaults to #{default}.") do |force|
        @opts[:force] = force
      end

      opts.on('--[no-]global',
              'Indicates whether the folders are global',
              '(i.e., is not stored within a simpkv folder',
              'for a Puppet environment).',
              "Defaults to #{@opts[:global]}." ) do |global|
        @opts[:global] = global
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
        err_msg = 'Folders to remove are missing from command line'
        raise Simp::Cli::ProcessingError, err_msg
      else
        @opts[:folders] = remaining_args[0].split(',')
      end
    end
  end

end
