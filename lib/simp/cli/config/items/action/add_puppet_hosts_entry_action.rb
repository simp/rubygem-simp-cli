require_relative '../action_item'
require_relative '../data/simp_options_puppet_server'
require_relative '../data/cli_puppet_server_ip'
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::AddPuppetHostsEntryAction < ActionItem
    attr_accessor :file

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'puppet::hosts_entry'
      @description = 'Ensure Puppet server /etc/hosts entry exists'
      @file        = '/etc/hosts'
      @category    = :puppet_env  # :system is also appropriate...
    end

    def apply
      @applied_status = :failed

      puppet_server    = get_item( 'simp_options::puppet::server' ).value
      puppet_server_ip = get_item( 'cli::puppet::server::ip' ).value

      backup_file = "#{@file}.#{@start_time.strftime('%Y%m%dT%H%M%S')}"
      info( "Backing up #{@file} to #{backup_file}" )
      FileUtils.cp(@file, backup_file)

      info( "Updating #{@file}" )

      values = Array.new
      File.readlines(@file).each do |line|
        # TODO Do we really want to remove comments?
        next if line =~ /\s*#/
        next if line.strip.empty?
        next if line =~ /#{puppet_server}/
        next if line =~ /^\s*127\.0\.0\.1\s+/
        next if line =~ /^\s*::1\s+/
        next if line =~ /\spuppet(\s|$)/  # remove alias 'puppet'
        values.push(line)
      end
      File.open(@file,'w') {|fh|
        fh.puts('127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4')
        fh.puts('::1 localhost localhost.localdomain localhost6 localhost6.localdomain6')
        fh.puts("#{puppet_server_ip} #{puppet_server} #{puppet_server.split('.').first}")
        fh.puts(values)
      }
      @applied_status = :succeeded
    end

    def apply_summary
      "Update to #{@file} to ensure puppet server entries exist #{@applied_status}"
    end
  end
end
