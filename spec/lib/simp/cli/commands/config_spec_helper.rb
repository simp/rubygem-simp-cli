require 'yaml'

# Create StringIO corresponding to user input for the simp
# scenario in which the default values are accepted.
# FIXME:  This input is INCORRECT if /etc/yum.repos.d/simp_filesystem.repo exists.
def generate_simp_input_accepting_defaults
  input_io = StringIO.new
  input_io                        <<
    "\n"                          << # when empty defaults to 'simp' scenario
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
    "\n"                          << # set production env to simp
    "\n"                          << # use internet SIMP repos
    "\n"                          << # SIMP is LDAP server
    "\n"                          << # don't auto-generate a password
    "iTXA8O6yC=DMotMGPTeHd7IGI\n" << # LDAP root password
    "iTXA8O6yC=DMotMGPTeHd7IGI\n" << # confirm LDAP root password
    "\n"                          << # log servers
    "\n"                          << # securetty list
    "\n"                             # svckill warning mode
  input_io.rewind
  input_io
end

# Create StringIO corresponding to user input for the simp_lite
# scenario in which the most values are set to user-provided values.
# Exercises LDAP-enabled, but non-LDAP server logic.
# FIXME:  This input is INCORRECT if /etc/yum.repos.d/simp_filesystem.repo exists.
def generate_simp_lite_input_setting_values
  input_io = StringIO.new
  input_io                                    <<
    "simp_lite\n"                             << # 'simp_lite' scenario
    "\n"                                      << # use suggested interface, as has to be a valid one
    "no\n"                                    << # don't activate the interface
    "simp.test.local\n"                       << # FQDN of this system
    "1.2.3.4\n"                               << # IP addr of this system
    "255.255.255.0\n"                         << # netmask of this system
    "1.2.3.1\n"                               << # gateway
    "1.2.3.10\n"                              << # DNS servers
    "test.local\n"                            << # DNS domain search string
    "1.2.0.0/16\n"                            << # trusted networks
    "time-a.nist.gov\n"                       << # NTP time servers
    "no\n"                                    << # don't set the GRUB password
    "no\n"                                    << # don't set production env to simp
    "no\n"                                    << # don't use internet SIMP repos
    "no\n"                                    << # SIMP is not LDAP server
    "dc=test,dc=local\n"                      << # LDAP base DN
    "cn=hostAuth,ou=Hosts,dc=test,dc=local\n" << # LDAP bind DN
    "xXx}.9Xx9>x.x9OmbjG%%Exr0R3z8Mkm\n"      << # LDAP bind password
    "xXx}.9Xx9>x.x9OmbjG%%Exr0R3z8Mkm\n"      << # confirm LDAP bind password
    "cn=LDAPSync,ou=Hosts,dc=test,dc=local\n" << # LDAP sync DN
    "MCMD3u-iTXA8O6yCoD{ot}GPTeHd7{GI\n"      << # LDAP sync password
    "MCMD3u-iTXA8O6yCoD{ot}GPTeHd7{GI\n"      << # confirm LDAP sync password
    "ldap://puppet.test.local\n"              << # LDAP root master URI
    "ldap://puppet.test.local\n"              << # OpenLDAP server URIs
    "1.2.3.11\n"                              << # log servers
    "1.2.3.12\n"                              << # failover log servers
    "tty0\n"                                     # securetty list
  input_io.rewind
  input_io
end

# Create StringIO corresponding to user input for the 'poss'
# scenario in which most values are set to user-provided values.
# Exercises LDAP-disabled and SSSD-disabled logic.
# via user input.
# FIXME:  This input is INCORRECT if /etc/yum.repos.d/simp_filesystem.repo exists.
def generate_poss_input_setting_values
  input_io = StringIO.new
  input_io                <<
    "poss\n"              << # 'poss' scenario
    "\n"                  << # use suggested interface, as has to be a valid one
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
    "no\n"                << # don't set production env to simp
    "no\n"                << # don't use internet SIMP repos
    "no\n"                << # don't use LDAP
    "no\n"                << # use SSSD
    "1.2.3.11\n"          << # log servers
    "1.2.3.12\n"          << # failover log servers
    "tty0\n"                 # securetty list
  input_io.rewind
  input_io
end

def config_normalize(file, other_keys_to_exclude = [])
  # These config items whose values cannot be arbitrarily set
  # and/or vary each time they run.
  min_exclude_set = Set.new [
     'simp_options::fips',                 # set by FIPS mode on running system which we can't control
     'cli::network::interface',            # depends upon actual interfaces available
     'grub::password',                     # hash value that varies from run-to-run with same password
     'simp_options::ldap::bind_hash',      # hash value that varies from run-to-run with same password
     'simp_options::ldap::sync_hash',      # hash value that varies from run-to-run with same password
     'simp_options::ntpd::servers',        # depends upon actual system configuration
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
  yaml_hash
end

def get_valid_interface
   interfaces =  Facter.value('interfaces').split(',').delete_if{|x| x == 'lo'}.sort
   (
     interfaces.select{|x|  x.match(/^br/)}.first  ||
     interfaces.select{|x|  x.match(/^eth/)}.first ||
     interfaces.select{|x| x.match(/^em/)}.first   ||
     interfaces.first
   )
end

