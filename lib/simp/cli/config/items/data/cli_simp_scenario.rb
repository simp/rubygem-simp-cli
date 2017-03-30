require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliSimpScenario < Item
    def initialize
      super
      @key         = 'cli::simp::scenario'
#TODO Generate description and validation based on available
# scenarios/*_items.yaml
      @description = %Q{SIMP scenario

'simp'      = Settings for a full SIMP system. Both the SIMP server
              (this host) and all clients will be running with
              all security features enabled.
'simp_lite' = Settings for a SIMP system in which some security features
              are disabled for SIMP clients.  The SIMP server will
              be running with all security features enabled.
'poss'      = Settings for a SIMP system in which all security features
              for the SIMP clients are disabled.  The SIMP server will
              be running with all security features enabled.
}
      @data_type  = :cli_params
    end

    def os_value
      site_pp = File.join(::Utils.puppet_info[:simp_environment_path],
        'manifests', 'site.pp')

      # If SIMP has not be copied over to the Puppet environments yet, (RPM install
      # not ISO or R10K install), this file won't be present
      return nil unless File.exist?(site_pp)

      scenario_lines = IO.readlines(site_pp).delete_if do |line|
        !(line =~ /^\$simp_scenario\s*=\s*['"]*(\S+)['"]/)
      end
      return nil if scenario_lines.size != 1

      scenario_lines[0].match(/^\$simp_scenario\s*=\s*['"]*(\S+)['"]/)[1]
    end

    def recommended_value
      'simp'
    end

    def validate( x )
      ['simp', 'simp_lite', 'poss'].include?(x)
    end

    def not_valid_message
      'Must be "simp", "simp_lite", or "poss"'
    end
  end
end
