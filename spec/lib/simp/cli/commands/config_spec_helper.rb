require 'test_utils/string_io'
require 'yaml'

# Create TestUtils::StringIO corresponding to user input for the simp
# scenario in which the default values are accepted.
def generate_simp_input_accepting_defaults(ask_if_ready = true)
  input_io = TestUtils::StringIO.new
  if ask_if_ready
    input_io << "\n"                 # empty defaults to yes, we are ready for the questionnaire
  end
  input_io                        <<
    "\n"                          << # empty defaults to 'simp' scenario
    "\n"                          << # use suggested interface, as has to be a valid one
    "\n"                          << # activate the interface
    "\n"                          << # static IP
    "\n"                          << # FQDN of this system
    "\n"                          << # IP addr of this system
    "\n"                          << # netmask of this system
    "\n"                          << # gateway
    "\n"                          << # DNS servers
    "\n"                          << # DNS domain search string
    "\n"                          << # trusted networks
    "\n"                          << # NTP time servers
    "\n"                          << # set GRUB password
    "\n"                          << # auto-generate GRUB password
    "\n"                          << # Press enter to continue
    "\n"                          << # use internet SIMP repos
    "\n"                          << # SIMP is LDAP server
    "\n"                          << # don't auto-generate a password
    "iTXA8O6yC=DMotMGP!eHd7IGI\n" << # LDAP root password
    "iTXA8O6yC=DMotMGP!eHd7IGI\n" << # confirm LDAP root password
    "\n"                          << # log servers
    "\n"                          << # securetty list
    "\n"                          << # ensure a privileged local user
    "\n"                          << # used 'simpadmin' as local username
    "P@ssw0rdP@ssw0rd!\n"         << # simpadmin password
    "P@ssw0rdP@ssw0rd!\n"         << # confirm simpadmin password
    "\n"                             # svckill warning mode
  input_io.rewind
  input_io
end

# Create TestUtils::StringIO corresponding to user input for the simp_lite
# scenario in which the most values are set to user-provided values.
# Exercises LDAP-enabled, but non-LDAP server logic.
def generate_simp_lite_input_setting_values
  input_io = TestUtils::StringIO.new
  input_io                        <<
    "yes\n"                       << # we are ready for the questionnaire
    "simp_lite\n"                 << # 'simp_lite' scenario
    "enp0s3\n"                    << # use interface from mocked fact
    "no\n"                        << # don't activate the interface
    "simp.test.local\n"           << # FQDN of this system
    "1.2.3.4\n"                   << # IP addr of this system
    "255.255.255.0\n"             << # netmask of this system
    "1.2.3.1\n"                   << # gateway
    "1.2.3.10\n"                  << # DNS servers
    "test.local\n"                << # DNS domain search string
    "1.2.0.0/16\n"                << # trusted networks
    "time-a.nist.gov\n"           << # NTP time servers
    "no\n"                        << # don't set the GRUB password
    "no\n"                        << # don't use internet SIMP repos
    "no\n"                        << # SIMP is not LDAP server
    "LOCAL\n"                     << # sssd domain
    "1.2.3.11\n"                  << # log servers
    "1.2.3.12\n"                  << # failover log servers
    "tty0\n"                      << # securetty list
    "yes\n"                       << # ensure a privileged local user
    "local_admin\n"               << # used 'local_admin' as local username
    "P@ssw0rdP@ssw0rd!\n"         << # local_admin password
    "P@ssw0rdP@ssw0rd!\n"            # confirm local_admin password
  input_io.rewind
  input_io
end

# Create TestUtils::StringIO corresponding to user input for the 'poss'
# scenario in which most values are set to user-provided values.
# Exercises LDAP-disabled and SSSD-disabled logic.
# via user input.
def generate_poss_input_setting_values
  input_io = TestUtils::StringIO.new
  input_io                <<
    "yes\n"               << # we are ready for the questionnaire
    "poss\n"              << # 'poss' scenario
    "enp0s3\n"            << # use interface from mocked fact
    "no\n"                << # don't activate the interface
    "simp.test.local\n"   << # FQDN of this system
    "1.2.3.4\n"           << # IP addr of this system
    "255.255.255.0\n"     << # netmask of this system
    "1.2.3.1\n"           << # gateway
    "1.2.3.10\n"          << # DNS servers
    "test.local\n"        << # DNS domain search string
    "1.2.0.0/16\n"        << # trusted networks
    "time-a.nist.gov\n"   << # NTP time servers
    "no\n"                << # don't set the GRUB password
    "no\n"                << # don't use internet SIMP repos
    "no\n"                << # don't use LDAP
    "no\n"                << # use SSSD
    "1.2.3.11\n"          << # log servers
    "1.2.3.12\n"          << # failover log servers
    "tty0\n"              << # securetty list
    "no\n"                   # do not ensure a privileged local user
  input_io.rewind
  input_io
end

def config_normalize(file, other_keys_to_exclude = [], overrides = {})
  # These config items whose values cannot be arbitrarily set
  # and/or vary each time they run.
  min_exclude_set = Set.new [
     'cli::local_priv_user_password',      # hash value that varies from run-to-run with same password
     'grub::password',                     # hash value that varies from run-to-run with same password
     'simp_options::ldap::bind_hash',      # hash value that varies from run-to-run with same password
     'simp_options::ldap::sync_hash',      # hash value that varies from run-to-run with same password
     'simp_options::ntp::servers',         # depends upon actual system configuration
     'simp_openldap::server::conf::rootpw' # hash value that varies from run-to-run with same password
  ]

  exclude_set = min_exclude_set.merge(other_keys_to_exclude)

  yaml_hash = YAML.load(File.read(file))
  yaml_hash = {} if !yaml_hash.is_a?(Hash) # empty YAML file returns false
  exclude_set.each do |key|
    if yaml_hash.key?(key)
      if yaml_hash[key].is_a?(Array)
        yaml_hash[key] = [ 'value normalized' ]
      else
        yaml_hash[key] = 'value normalized'
      end
    end
  end
  yaml_hash.merge(overrides).merge('cli::version' => Simp::Cli::VERSION)
end
