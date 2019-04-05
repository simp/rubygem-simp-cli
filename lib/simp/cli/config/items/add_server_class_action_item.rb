require 'simp/cli/config/items/action_item'
require 'simp/cli/utils'

module Simp::Cli::Config

  # An ActionItem that adds an entry to a class list in the SIMP server's
  # <host>.yaml file
  # Derived class must set @key and @class_to_add
  class AddServerClassActionItem < ActionItem
    attr_accessor :dir

    def initialize
      super
      @dir         = File.join(Simp::Cli::Utils.simp_env_datadir, 'hosts')
      @description = "Add #{@class_to_add} class to SIMP server <host>.yaml"
      @file        = nil
      @category    = :puppet_env_server
    end

    def apply
      raise InternalError.new( "@class_to_add empty for #{self.class}" ) if "#{@class_to_add}".empty?

      @applied_status = :failed
      fqdn    = get_item( 'cli::network::hostname' ).value
      @file    = File.join( @dir, "#{fqdn}.yaml")

      if File.exists?(@file)
        debug( "Adding #{@class_to_add} to the class list in #{fqdn}.yaml file", [:GREEN] )
        yaml = IO.readlines(@file)

        File.open(@file, 'w') do |f|
          yaml.each do |line|
            line.chomp!
            if line =~ /^classes\s*:/
              f.puts line
              f.puts "  - '#{@class_to_add}'"
            else
              f.puts line unless contains_class?(line)
            end
          end
        end
        @applied_status = :succeeded
      else
        error( "\nERROR: file not found: #{@file}", [:RED] )
      end
    end

    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Addition of #{@class_to_add} to #{file} class list #{@applied_status}"
    end

    # whether a line from the YAML file contains the class
    def contains_class?(line)
      return line.=~ /^\s*-\s+['"]*#{@class_to_add}['"]*/
    end
  end
end
