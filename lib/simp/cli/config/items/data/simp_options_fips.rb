require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsFips < YesNoItem

    def initialize
      super
      @key         = 'simp_options::fips'
      @description = %Q{Prepare system to use FIPS mode.

#{@key} enforces strict compliance with FIPS-140-2.  All core SIMP modules
can support this configuration. Enabling simp_options::fips here will enable
FIPS on this puppet environment.

IMPORTANT:
(1) Be sure you know the security tradeoffs of FIPS-140-2 compliance.
    FIPS mode disables the use of MD5 and may require weaker ciphers or key
    lengths than your security policies allow.
(2) If the system is currently in FIPS mode and you set this option to false,
    the system will still work.  The reverse is not necessarily true.  See
    SIMP documentation for instructions on how to safely convert a non-FIPS
    system to a FIPS system.
}
    end

    def get_os_value
      Facter.value('fips_enabled') ? 'yes' : 'no'
    end

    def get_recommended_value
      os_value
    end
  end
end
