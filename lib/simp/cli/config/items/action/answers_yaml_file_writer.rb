# frozen_string_literal: true

require_relative '../action_item'
require_relative '../../items'
require 'fileutils'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::AnswersYAMLFileWriter < ActionItem
    attr_accessor :file, :sort_output

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super

      @key             = 'yaml::answers_file_writer'
      @description     = %(Write answers to YAML file.)
      @file            = '~/.simp/simp_conf.yaml'
      @sort_output     = true
      @category        = :answers_writer
    end

    # prints an answers file to an iostream
    def print_answers_yaml(iostream, answers)
      scenario_info = if @config_items['cli::simp::scenario']
                        "for '#{@config_items['cli::simp::scenario'].value}' scenario "
                      else
                        ''
                      end
      iostream.puts '#' + ('=' * 72)
      iostream.puts '# simp config answers'
      iostream.puts '#'
      iostream.puts "# Generated #{scenario_info}on #{@start_time.strftime('%F %T')}"
      iostream.puts '#' + ('-' * 72)
      iostream.puts "# You can use these answers to quickly configure subsequent
                     # simp installations by running the command:
                     #
                     #   simp config -A /PATH/TO/THIS/FILE
                     #
                     # simp config will prompt for any missing items.
                     #
                     # NOTE:
                     # - All YAML keys that begin with 'cli::' are used by
                     #   simp config, internally, and are not Puppet hieradata.
                     # - Some entries have been automatically determined by
                     #   `simp config` based on the values of other entries
                     #   and/or gathered server status.
                     ".gsub(%r{^\s+}, '').strip
      iostream.puts '#' + ('=' * 72)
      iostream.puts '---'
      iostream.puts '# === cli::version ==='
      iostream.puts '# The version of simp-cli used to generate this file.'
      iostream.puts "cli::version: \"#{Simp::Cli::VERSION}\""
      iostream.puts

      if @sort_output
        answers = answers.sort.to_h
      end

      answers.each_value do |v|
        next unless v.data_type && v.data_type != :internal && (yaml = v.to_yaml_s) # filter out nil results for items whose YAML is suppressed

        # get rid of trailing whitespace
        yaml.split("\n").each { |line| iostream.puts line.rstrip }
        iostream.puts
      end
    end

    # write a file and returns the number of bytes written
    def write_answers_yaml_file(file, answers)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, 'w') { |fh| print_answers_yaml(fh, answers) }
    end

    def apply
      @applied_status = :failed
      write_answers_yaml_file(@file, @config_items) if @config_items.size.positive?
      @applied_status = :succeeded
    end

    def apply_summary
      if @applied_status == :succeeded
        "#{@file} created"
      else
        "Creation of #{@file} #{@applied_status}"
      end
    end
  end
end
