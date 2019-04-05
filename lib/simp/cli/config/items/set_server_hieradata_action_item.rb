require 'yaml'
require 'simp/cli/config/items/action_item'
require 'simp/cli/utils'

module Simp::Cli::Config
  # An ActionItem that adds/updates a hieradata key in the SIMP server's
  # <host>.yaml file
  # Derived class must set @key and @hiera_to_add where @key must be
  # unique and @hiera_to_add is an array of hiera keys
  class SetServerHieradataActionItem < ActionItem

    def initialize
      super
      @dir         = File.join(Simp::Cli::Utils.simp_env_datadir, 'hosts')
      @description = "Set #{@hiera_to_add.join(', ')} in SIMP server <host>.yaml"
      @file        = nil
      @category    = :puppet_env_server
    end

    def apply
       "#{@hiera_to_add} not set!" if @hiera_to_add.nil?

      @applied_status = :failed
      fqdn  = get_item( 'cli::network::hostname' ).value
      @file = File.join( @dir, "#{fqdn}.yaml")

      if File.exists?(@file)
        @hiera_to_add.each do |key|
          verify_item_present(key)

          yaml_hash = YAML.load(IO.read(@file))
          if yaml_hash.key?(key)
            replace_line(key)
          else
            add_yaml_entry(key)
          end
          @applied_status = :succeeded
        end
      else
        error( "\nERROR: file not found: #{@file}", [:RED] )
      end
    end

    def add_yaml_entry(hiera_key)
      hiera_item = @config_items.fetch( hiera_key )
      full_yaml_string = hiera_item.to_yaml_s
      if full_yaml_string.nil?
        raise InternalError.new("YAML string for #{hiera_key} is not set")
      end

      debug( "Adding #{hiera_key} to #{File.basename(@file)}" )
      yaml = IO.readlines(@file)
      line_written = false
      File.open(@file, 'w') do |f|
        yaml.each do |line|
          line.chomp!
          if line =~ /^classes\s*:/
            f.puts full_yaml_string
            f.puts line
            line_written = true
          else
            f.puts line
          end
        end

        unless line_written
          f.puts full_yaml_string
        end
      end
    end

    def replace_line(hiera_key)
      hiera_item = @config_items.fetch( hiera_key )
      full_yaml_string = hiera_item.to_yaml_s
      if full_yaml_string.nil?
        raise InternalError.new("YAML string for #{hiera_key} is not set")
      end

      full_yaml_lines = full_yaml_string.split("\n")
      # remove comment lines
      yaml_line = full_yaml_lines.select { |line| line =~ /^#{hiera_key}\s*:/ }
      if yaml_line.empty?
        raise InternalError.new("YAML string for #{hiera_key} missing <key: value> line")
      end
      yaml_line = yaml_line[0]

      debug( "Replacing #{hiera_key} in #{File.basename(@file)}" )
      yaml = IO.readlines(@file)
      File.open(@file, 'w') do |f|
        yaml.each do |line|
          line.chomp!
          if line =~ /^#{hiera_key}\s*:/
            f.puts yaml_line
          else
            f.puts line
          end
        end
      end
    end

    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      key_list = @hiera_to_add.join(', ')
      "Setting of #{key_list} in #{file} #{@applied_status}"
    end
  end
end
