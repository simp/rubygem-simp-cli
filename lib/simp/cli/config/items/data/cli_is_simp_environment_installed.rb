require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliIsSimpEnvironmentInstalled < YesNoItem
    attr_accessor :adapter_config
    def initialize
      super
      @key         = 'cli::is_simp_environment_installed'
      @description = %q{Whether the SIMP modules are already installed in
the Puppet environments directory.}


      @data_type      = :internal # don't persist this as it needs to be
                                  # evaluated each time simp config is run
      @adapter_config = '/etc/simp/adapter_config.yaml'
    end


    def get_os_value
      # SIMP can be installed via an ISO, individual RPMs or R10K.  When SIMP
      # is installed from an ISO or R10K, the SIMP modules are automatically
      # copied into the Puppet environments directory.  When SIMP is
      # installed via individual RPMs, this copy is not done. We detect
      # the last case as follows:
      # - /etc/simp/adapter_config.yaml exists
      # - 'copy_rpm_data' key has a value of false
      if File.exist?(@adapter_config)
        begin
          yaml = YAML.load(File.read(@adapter_config))
          if yaml.nil? or yaml == false
            return 'no'
          else
            return ( (yaml['copy_rpm_data'] == true) ? 'yes' : 'no' )
          end
        rescue Psych::SyntaxError
          # something wrong with the YAML file, so we are
          # going to assume the copy did not happen
          return 'no'
        end
      else
        return 'yes' # must be a R10K installation, as no simp_adapter RPM
      end
    end

    def get_recommended_value
      os_value
    end
  end
end
