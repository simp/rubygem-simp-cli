require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliHasSimpFilesystemYumRepo < YesNoItem
    attr_accessor :local_repo
    def initialize
      super
      @key         = 'cli::has_simp_filesystem_yum_repo'
      @description = %q{Whether the server can provide on-server,
OS, SIMP, and SIMP dependency packages.

When SIMP is installed from an ISO, the system contains a
/etc/yum.repos.d/simp_filesystem.repo file, that has YUM
configuration for on-server repositories providing OS,
SIMP, and SIMP dependency packages.}
      @data_type  = :internal  # don't persist this as it needs to be
                               # evaluated each time simp config is run
      @local_repo = '/etc/yum.repos.d/simp_filesystem.repo'
    end


    def get_os_value
      (File.exist?(@local_repo) ? 'yes' : 'no')
    end

    def get_recommended_value
      os_value
    end
  end
end
