require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )
module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::PuppetAutosign < ActionItem
    attr_accessor :file
    def initialize
      super
      @key         = 'puppet::autosign'
      @description = %Q{By default, the only host eligible for autosign is the Puppet master; action-only.}
      @file        = '/etc/puppet/autosign.conf'
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
      item = os_value
      if !item
        item = @config_items.fetch( 'hostname', nil )
        item = [ item.value ] if item
      end
      item
    end

    def apply
      @applied_status = :failed
      entries = recommended_value
      say_green "Updating #{@file}..." if !@silent
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
      @applied_status = :applied
    end

    def apply_summary
      "Setup of autosign in #{@file} #{@applied_status}"
    end
  end
end
