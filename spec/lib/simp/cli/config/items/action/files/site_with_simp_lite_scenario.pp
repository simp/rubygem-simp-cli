# Set the global Exec path to something reasonable
Exec {
  path => [
    '/usr/local/bin',
    '/usr/local/sbin',
    '/usr/bin',
    '/usr/sbin',
    '/bin',
    '/sbin'
  ]
}

# SIMP Scenarios
#
# Set this variable to make use of the different class sets in heiradata/scenarios,
#   mostly applicable to puppet agents, or, the SIMP server overrides some of these.
#   * `simp` - compliant and secure
#   * `simp_lite` - makes use of many of our modules, but doesn't apply
#        many prohibitive security or compliance features, svckill
#   * `poss` - only include pupmod by default to configure the agent
$simp_scenario = 'simp_lite'

# Map SIMP parameters to NIST Special Publication 800-53, Revision 4
# See modules/compliance_markup/data/compliance_profiles for more options.
$compliance_profile = 'nist_800_53_rev4'

# Place Hiera customizations based on this variable in data/hostgroups/${::hostgroup}.yaml
#
# Example hostgroup declaration using a regex match on the hostname:
#   case $facts['fqdn'] {
#     /dns\d+\.example.domain/:    { $hostgroup = 'dns'     }
#     /gitlab\d+\.example.domain/: { $hostgroup = 'gitlab'  }
#     default:                     { $hostgroup = 'default' }
#   }
#
$hostgroup = 'default'

# Required if you want the SIMP global catalysts
# Defaults should technically be sane in all modules without this
include 'simp_options'
# Include the SIMP base controller with the preferred scenario
include 'simp'

# Hiera class lookups and inclusions (replaces `hiera_include()`)
$hiera_classes          = lookup('classes',          Array[String], 'unique', [])
$hiera_class_exclusions = lookup('class_exclusions', Array[String], 'unique', [])
$hiera_included_classes = $hiera_classes - $hiera_class_exclusions

include $hiera_included_classes

# For proper functionality, the compliance_markup list needs to be included *absolutely last*
include compliance_markup
