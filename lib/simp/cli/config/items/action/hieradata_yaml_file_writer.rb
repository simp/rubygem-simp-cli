require 'simp/cli/config/items'
require 'simp/cli/version'
require 'fileutils'

module Simp::Cli::Config
  class Item::HieradataYAMLFileWriter < ActionItem
    attr_accessor :file

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)

      @key             = 'yaml::hieradata_file_writer'
      @description     = %Q{Write SIMP global hieradata to YAML file.}
      # 'simp cli' sets @file, so this default doesn't really matter
      @file            = Simp::Cli::CONFIG_GLOBAL_HIERA_FILENAME
      @group           = @puppet_env_info[:puppet_group]
      @category        = :puppet_env
    end

    # prints an hieradata file to an iostream
    def print_hieradata_yaml( iostream, answers )
      if @config_items['cli::simp::scenario']
         scenario_info = "for '#{@config_items['cli::simp::scenario'].value}' scenario "
      else
         scenario_info = ''
      end
      iostream.puts '#' + '='*72
      iostream.puts '# SIMP global configuration'
      iostream.puts '#'
      iostream.puts "# Generated #{scenario_info}on #{@start_time.strftime('%F %T')}"
      iostream.puts "# using simp-cli version #{Simp::Cli::VERSION}"
      iostream.puts '#' + '='*72
      iostream.puts '---'
      global_classes = []
      answers.sort.to_h.each do |k,v|
        if v.data_type
          if v.data_type == :global_hiera
            if yaml = v.to_yaml_s  # filter out nil results for items whose YAML is suppressed
              # get rid of trailing whitespace
              yaml.split("\n").each { |line| iostream.puts line.rstrip }
              iostream.puts
            end
          elsif v.data_type == :global_class
            # gather up the classes to be added to a  'simp::classes' sequence at the end of the file
            global_classes << v.key
          end
        end
      end

      unless global_classes.empty?
        iostream.puts
        iostream.puts(pair_to_yaml_tag('simp::classes', global_classes))
      end
    end


    # write a file and returns the number of bytes written
    def write_hieradata_yaml_file( file, answers )
      info( "Writing hieradata to: #{file}" )
      # Shouldn't need to create the directory (except possibly for
      # unit tests), as CopySimpToEnvironmentsAction, a preceeding item,
      # *guarantees* the 'simp' environment is present.  As such, we are
      # not going to worry about the ownership/permissions of each part
      # of this path.
      FileUtils.mkdir_p( File.dirname( file ) )
      File.open( file, 'w' ){ |fh| print_hieradata_yaml( fh, answers ) }
    end

    def apply
      @applied_status = :failed

      if File.exist?(@file)
         backup_file = "#{@file}.#{@start_time.strftime('%Y%m%dT%H%M%S')}"
         info( "Backing up #{@file} to #{backup_file}" )
         FileUtils.cp(@file, backup_file)
         group_id = File.stat(@file).gid
         File.chown(nil, group_id, backup_file)
      end

      begin
        write_hieradata_yaml_file( @file, @config_items ) if @config_items.size > 0
        FileUtils.chmod(0640, @file)
        FileUtils.chown(nil, @group, @file)
        @applied_status = :succeeded
      rescue Errno::EPERM, ArgumentError => e
        # This will happen if the user is not root or the group does
        # not exist.
        error( "\nERROR: Could not write #{@file} with group '#{@group}': #{e}", [:RED] )
      end
    end

    def apply_summary
      brief_filename = @file.gsub(%r{.*environments},'/etc/.../environments')
      if @applied_status == :succeeded
        "#{brief_filename} created"
      else
        "Creation of #{brief_filename} #{@applied_status}"
      end
    end
  end
end
