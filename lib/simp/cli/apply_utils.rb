require 'simp/cli/exec_utils'

require 'yaml'
require 'tmpdir'

module Simp; end
class Simp::Cli; end

module Simp::Cli::ApplyUtils

  # Apply a Puppet manifest in an environment via a spawned process
  #
  # @param manifest Contents of the manifest to be applied
  # @param opts Options
  #  * :env   - Puppet environment to which manifest will be applied.
  #             Defaults to 'production' when unspecified.
  #  * :group - Group to run Puppet apply as.  When specified, puppet apply
  #             is wrapped within 'sg <group>'.
  #  * :fail  - Whether to raise an exception upon manifest failure.
  #             Defaults to true when unspecified
  #  * :fail_filter - Error message to search for in the stderr output of a
  #             failed apply and then use as the (simplified) failure message
  #             if found. Only applies when :fail is true. Useful when a
  #             manifest has logic to detect and report a specific failure.
  #  * :puppet_config - Hash of Puppet configuration to set for the
  #            command.  Defaults to {}.
  #  * :title - Brief description of operation. Used in the exception
  #             message when apply fails and :fail is true.
  #             Defaults to 'puppet apply' when unspecified.
  #
  # @param logger Optional Simp::Cli::Logging::Logger object. When not
  #    set, logging is suppressed.
  #
  # @raise Simp::Cli::ProcessingError if manifest apply fails and :fail is true
  #
  def self.apply_manifest_with_spawn(manifest, opts = {}, logger = nil)
    options = opts.dup
    options[:env]           = 'production'   unless options.key?(:env)
    options[:fail]          = true           unless options.key?(:fail)
    options[:puppet_config] = {}             unless options.key?(:puppet_config)
    options[:title]         = 'puppet apply' unless options.key?(:title)

    result = nil
    cmd = nil
    Dir.mktmpdir( File.basename( __FILE__ ) ) do |dir|
      logger.debug("Creating manifest file for #{options[:title]} with" +
        " content:\n\n#{manifest}\n") if logger

      manifest_file = File.join(dir, 'apply_manifest.pp')
      File.open(manifest_file, 'w') { |file| file.puts manifest }
      puppet_apply = [
        'puppet apply',
        '--color=false',
        "--environment=#{options[:env]}",
        options[:puppet_config].map { |cfg,value| "--#{cfg}=#{value}"}.join(' '),
        manifest_file
      ].join(' ')

      cmd = nil
      if options[:group]
        cmd = "sg #{options[:group]} -c '#{puppet_apply}'"
      else
        cmd = puppet_apply
      end

      # We need to defer handling of error logging to the caller, so don't pass
      # logger into run_command().  Since we are not using the logger in
      # run_command(), we will have to duplicate the command debug logging here.
      logger.debug( "Executing: #{cmd}" ) if logger
      result = Simp::Cli::ExecUtils.run_command(cmd)
    end

    if logger
      logger.debug(">>> stdout:\n#{result[:stdout]}")
      logger.debug(">>> stderr:\n#{result[:stderr]}")
    end

    if !result[:status] && options[:fail]
      err_msg = nil
      if ( options.key?(:fail_filter) &&
          result[:stderr].include?(options[:fail_filter]) )
        err_msg = options[:fail_filter]
      else
        stderr = result[:stderr].split("\n")
        stderr.delete_if { |line| line.match(/^\s*Error/).nil? }
        stderr.map! { |line| "    #{line}" }
        err_msg = "#{options[:title]} failed:\n#{stderr.join("\n")}"
      end

      raise Simp::Cli::ProcessingError, err_msg
    end

    result
  end

=begin
TODO
  def self.apply_manifest_with_pal(manifest, ..., logger = nil)
  end
=end


  # Load YAML from a temporary file and return the resulting Hash
  #
  # Useful for gathering results persisted to a temporary YAML file
  # during a 'puppet apply' operation.
  #
  # @param file Name of temporary file to load
  # @param id identifier to print in messages in lieu of meaningless
  #   temporary filename
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
      raise Simp::Cli::ProcessingError, err_msg
    end

    yaml
  end

end
