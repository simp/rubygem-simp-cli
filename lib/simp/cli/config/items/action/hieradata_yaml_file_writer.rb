require 'simp/cli/version'
require File.expand_path( '../action_item', File.dirname(__FILE__) )
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::HieradataYAMLFileWriter < ActionItem
    attr_accessor :file, :group

    def initialize
      super

      @key             = 'yaml::hieradata_file_writer'
      @description     = %Q{Write SIMP global hieradata to YAML file.}
      @file            = "#{::Utils.puppet_info[:simp_environment_path]}/hieradata/simp/site/simp_config_overrides.yaml"
      @group           = ::Utils.puppet_info[:puppet_group]
    end

    # prints an hieradata file to an iostream
    def print_hieradata_yaml( iostream, answers )
      if @config_items['cli::simp::scenario']
         scenario_info = "for #{@config_items['cli::simp::scenario'].value} scenario "
      else
         scenario_info = ''
      end
      iostream.puts "#" + '='*72
      iostream.puts "# SIMP global configuration"
      iostream.puts "#"
      iostream.puts "# Generated #{scenario_info}on #{@start_time.strftime('%F %T')}"
      iostream.puts "# using simp-cli version #{Simp::Cli::VERSION}"
      iostream.puts "#" + '='*72
      iostream.puts "---"
      answers.sort.to_h.each do |k,v|
        if v.data_type and (v.data_type == :global_hiera )
          if yaml = v.to_yaml_s  # filter out nil results for items whose YAML is suppressed
            # get rid of trailing whitespace
            yaml.split("\n").each { |line| iostream.puts line.rstrip }
            iostream.puts
          end
        end
      end
    end


    # write a file and returns the number of bytes written
    def write_hieradata_yaml_file( file, answers )
      debug( "Writing hieradata to: #{file}" )
      FileUtils.mkdir_p( File.dirname( file ) )
      File.open( file, 'w' ){ |fh| print_hieradata_yaml( fh, answers ) }
    end

    def apply
      @applied_status = :failed

      if File.exist?(@file)
         backup_file = "#{@file}.#{@start_time.strftime('%Y%m%dT%H%M%S')}"
         debug( "Backing up #{@file} to #{backup_file}" )
         FileUtils.cp(@file, backup_file)
         group_id = File.stat(@file).gid
         File.chown(nil, group_id, backup_file)
      end

      write_hieradata_yaml_file( @file, @config_items ) if @config_items.size > 0
      FileUtils.chmod(0640, @file)
      begin
        FileUtils.chown(nil, @group, @file)
        @applied_status = :succeeded
      rescue Errno::EPERM, ArgumentError => e
        # This will happen if the user is not root or the group does
        # not exist.
        error( "\nERROR: Could not change ownership of\n    #{@file} to '#{@group}' group", [:RED] )
      end
    end

    def apply_summary
      brief_filename = @file.gsub(%r{.*environments},'.../environments')
      if @applied_status == :succeeded
        "#{brief_filename} created"
      else
        "Creation of #{brief_filename} #{@applied_status}"
      end
    end
  end
end
