require File.expand_path( '../action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SetUpPuppetAutosignAction < ActionItem
    attr_reader :file
    def initialize
      super
      @key         = 'puppet::autosign'
      @description = 'Set up Puppet autosign'
      @file        = File.join(Simp::Cli::Utils.puppet_info[:config]['confdir'], 'autosign.conf')
      @group       = Simp::Cli::Utils.puppet_info[:puppet_group]
    end

    def get_os_value
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

    def get_recommended_value
      rec_value = os_value
      if !rec_value
        rec_value = [ get_item( 'cli::network::hostname' ).value ]
      end
      rec_value
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

      entries = recommended_value
      debug( "Updating #{@file}" )
      begin
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
        FileUtils.chmod(0640, @file)
        FileUtils.chown(nil, @group, @file)
        @applied_status = :succeeded
      rescue Errno::EPERM, ArgumentError => e
        # This will happen if the user is not root or the group does
        # not exist.
        error( "\nERROR: Could not create #{@file} with group '#{@group}': #{e}", [:RED] )
      end
    end

    def apply_summary
      "Setup of autosign in #{@file} #{@applied_status}"
    end
  end
end
