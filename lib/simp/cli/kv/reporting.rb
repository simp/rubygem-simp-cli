# frozen_string_literal: true

require 'simp/cli/command_console_logger'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Kv; end

module Simp::Cli::Kv::Reporting
  include Simp::Cli::CommandConsoleLogger

  # @returns key/folder description
  # @param entity Key/folder name
  # @param opts KV command options Hash
  def entity_description(entity, opts)
    if opts[:global]
      "global '#{entity}'"
    else
      "'#{entity}' in '#{opts[:env]}' environment"
    end
  end

  # Report results to console or file in JSON format
  #
  # @param id Identifier to be used in log/exception messages
  # @param results Results Hash
  # @param outfile Name of output file or nil
  #
  # @raise Simp::Cli::ProcessingError if file write fails
  def report_results(id, results, outfile)
    require 'json'
    require 'simp/cli/errors'

    begin
      json_string = JSON.pretty_generate(results)
    rescue JSON::JSONError => e
      err_msg = "Results could not be converted to JSON: #{e}"
      raise Simp::Cli::ProcessingError, err_msg
    end

    if outfile.nil?
      logger.say(json_string)
    else
      begin
        File.open(outfile, 'w') { |file| file.puts(json_string) }
        logger.notice("Output for #{id} written to #{outfile}")
      rescue Exception => e
        err_msg = "Failed to write #{id} output to #{outfile}: #{e}"
        raise Simp::Cli::ProcessingError, err_msg
      end
    end
  end
end
