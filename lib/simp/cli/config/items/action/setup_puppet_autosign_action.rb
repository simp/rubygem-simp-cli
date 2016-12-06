require File.expand_path( '../action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SetupPuppetAutosignAction < ActionItem
    attr_accessor :file
    def initialize
      super
      @key         = 'puppet::autosign'
      @description = 'Setup Puppet autosign'
      @file        = File.join(::Utils.puppet_info[:config]['confdir'], 'autosign.conf')
    end

    def os_value
      # TODO: make this a custom fact?
      values = Array.new
      File.readable?(@file) &&
      File.readlines(@file).each do |line|
        next if line =~ /^(\#|\s*$)/

        # if we encounter 'puppet.your.domain' (the default value from a
        # fresh simp-bootstrap RPM), infer this is a freshly installed system
        # with no legitimate autosign entries.
        if line =~ /^puppet.your.domain/
          values = []
          break
        end
        values << line.strip
      end
      if values.size == 0
        nil
      else
        values
      end
    end

    def recommended_value
      rec_value = os_value
      if !rec_value 
        rec_value = [ get_item( 'cli::network::hostname' ).value ]
      end
      rec_value
    end

    def apply
      @applied_status = :failed
      backup_file = "#{@file}.#{@start_time.strftime('%Y%m%dT%H%M%S')}"
      debug( "Backing up #{@file} to #{backup_file}" )
      FileUtils.cp(@file, backup_file)
      group_id = File.stat(@file).gid
      File.chown(nil, group_id, backup_file)

      entries = recommended_value
      debug( "Updating #{@file}" )
      File.open(@file, 'w') do |file|
        file.puts "# You should place any hostnames/domains here that you wish to autosign.\n" +
                  "# The most security-conscious method is to list each individual hostname:\n" +
                  "#   hosta.your.domain\n" +
                  "#   hostb.your.domain\n" +
                  "#\n" +
                  "# Wildcard domains work, but absolutely should NOT be used unless you fully\n" +
                  "# trust your network.\n" +
                  "#   *.your.domain\n\n"
        entries.each do |entry|
          file.puts(entry)
        end
      end
      @applied_status = :succeeded
    end

    def apply_summary
      "Setup of autosign in #{@file} #{@applied_status}"
    end
  end
end
