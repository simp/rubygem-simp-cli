module Simp; end

class Simp::Cli
  SIMP_CLI_HOME  = "#{ENV['HOME']}/.simp"
  BOOTSTRAP_START_LOCK_FILE = File.join(SIMP_CLI_HOME, 'simp_bootstrap_start_lock')
  SIMP_MODULES_INSTALL_PATH = '/usr/share/simp/modules'
  SIMP_MODULES_GIT_REPOS_PATH =  '/usr/share/simp/git/puppet_modules'
end

