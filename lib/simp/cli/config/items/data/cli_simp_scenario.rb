require_relative '../item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliSimpScenario < Item
    def initialize
      super
      @key         = 'cli::simp::scenario'
#TODO Generate description and validation based on available
# scenarios/*_items.yaml
      @description = %Q{The SIMP scenario: Predetermined set of security features to apply.

'simp'      = Settings for a full SIMP system. Both the SIMP server
              (this host) and all clients will be running with
              all security features enabled.
'simp_lite' = Settings for a SIMP system in which some security features
              are disabled for SIMP clients.  The SIMP server will
              be running with all security features enabled.
'poss'      = Settings for a SIMP system in which all security features
              for the SIMP clients are disabled.  The SIMP server will
              be running with all security features enabled.

NOTE:  If your site has different needs than provided by the predetermined
scenarios, you can always fine-tune the security settings after you have
bootstrapped your SIMP server.}
      @data_type  = :cli_params
    end

    def get_os_value
      site_pp = File.join(Simp::Cli::Utils.puppet_info[:simp_environment_path],
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

    def get_recommended_value
      'simp'
    end

    def validate( x )
      ['simp', 'simp_lite', 'poss'].include?(x)
    end

    def not_valid_message
      'Must be "simp", "simp_lite", or "poss"'
    end

    # Generate standard YAML output, but never include the auto warning
    # message.
    # FIXME: Override to solve a convoluted, `simp config` code problem.
    # Because `simp config` needs to know the scenario to use to build
    # the Item decision tree, it needs to determine this Item's value ahead
    # of time. Then, to make sure this Item is actually persisted in the YAML,
    # it gets added to # the tree with @skip_query and @silent both set to true.
    # This, in turn causes an inapplicable warning message to be added to the
    # Item's YAML (see Item#auto_warning and Item#to_yaml_s).
    def to_yaml_s(include_auto_warning = false)
      super(false)
    end
  end
end
