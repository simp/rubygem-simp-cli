require 'simp/cli/config/items/action_item'
require 'simp/cli/config/items/data/cli_network_hostname'

module Simp::Cli::Config

  # An ActionItem that adds an entry to a class list in the SIMP server's
  # <host>.yaml file
  #
  # - Derived class must set @key and @class_to_add
  # - Derived class should set @class_to_add before calling the constructor
  #   of this class to ensure the description is meaningful
  #
  class AddServerClassActionItem < ActionItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @dir         = File.join(@puppet_env_info[:puppet_env_datadir], 'hosts')
      @description = "Add #{@class_to_add} class to SIMP server <host>.yaml"
      @file        = nil
      @category    = :puppet_env_server
    end

    def apply
      if @class_to_add.to_s.strip.empty?
        raise InternalError.new( "@class_to_add empty for #{self.class}" )
      end

      @applied_status = :failed
      fqdn    = get_item( 'cli::network::hostname' ).value
      @file    = File.join( @dir, "#{fqdn}.yaml")

      if File.exist?(@file)
        begin
          file_info = load_yaml_with_comment_blocks(@file)
          classes_key = get_classes_key(file_info[:content].keys)
          if classes_key.nil?
            classes_key = 'simp::server::classes'
            info( "Adding #{classes_key} with #{@class_to_add} to #{File.basename(@file)}.", [:GREEN] )
            tag = pair_to_yaml_tag(classes_key, [ @class_to_add ])
            add_yaml_tag_directive(tag, file_info)
          else
            info( "Adding #{@class_to_add} to #{classes_key} in #{File.basename(@file)}.", [:GREEN] )
            merge_yaml_tag(classes_key, [ @class_to_add ], file_info)
          end

          @applied_status = :succeeded
        rescue InternalError => e
          # something is wrong with the decision tree yaml
          raise(e)
        rescue Exception => e
          error( "\nERROR: Unable to update #{@file}:\n#{e.message}", [:RED] )
        end
      else
        error( "\nERROR: file not found: #{@file}", [:RED] )
      end
    end

    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Addition of #{@class_to_add} to #{file} class list #{@applied_status}"
    end

    # @param Array of keys
    # @return which classes key is found in keys or nil if none is found
    def get_classes_key(keys)
      classes_key = nil
      if keys.include?('simp::server::classes')
        classes_key = 'simp::server::classes'
      elsif keys.include?('simp::classes')
        classes_key = 'simp::classes'
      elsif keys.include?('classes')
        classes_key = 'classes'
      end

      classes_key
    end
  end
end
