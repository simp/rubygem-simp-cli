module Simp; end

class Simp::Cli
# TODO Each of these configuration defaults should be overridable
# via a configuration file.  This is especially important for
# the install path defaults, when on a server that strictly uses
# Git to access SIMP asset files, such as those for the
# simp-environment-skeleton.
  SIMP_CLI_HOME                  = "#{ENV['HOME']}/.simp"
  BOOTSTRAP_PUPPET_ENV           = 'production'
  BOOTSTRAP_START_LOCK_FILE      = File.join(SIMP_CLI_HOME, 'simp_bootstrap_start_lock')
  CONFIG_ANSWERS_OUTFILE         = File.join(SIMP_CLI_HOME, 'simp_conf.yaml')
  CONFIG_GLOBAL_HIERA_FILENAME   = 'simp_config_settings.yaml'
  SIMP_INSTALL_ROOT              = '/usr/share/simp'
  SIMP_ENV_SKELETON_INSTALL_PATH = File.join(SIMP_INSTALL_ROOT, 'environments', 'simp')
  SIMP_MODULES_INSTALL_PATH      = File.join(SIMP_INSTALL_ROOT, 'modules')
  SIMP_MODULES_GIT_REPOS_PATH    = File.join(SIMP_INSTALL_ROOT, 'git', 'puppet_modules')
  CERTIFICATE_GENERATOR          = 'gencerts_nopass.sh'
  PUPPET_DIGEST_ALGORITHM        = 'sha256'  # MUST be a FIPS-compliant algorithm
  PE_ENVIRONMENT_PATH            = '/opt/puppetlabs/server/data/environments'
end
