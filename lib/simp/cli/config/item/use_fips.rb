require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::UseFips < YesNoItem
    include Simp::Cli::Config::SafeApplying

    def initialize
      super
      @key         = 'use_fips'
      @description = %q{Enable FIPS mode on this system.

FIPS mode enforces strict compliance with FIPS-140-2.  All core SIMP modules
can support this configuration.

IMPORTANT: Be sure you know the security tradeoffs of FIPS-140-2 compliance.
FIPS mode disables the use of MD5 and may require weaker ciphers or key lengths
than your security policies allow.
}
     @allow_user_apply = true
     @applied_status = 'not attempted'
    end

    def os_value
      Facter.value('fips_enabled') ? 'yes' : 'no'
    end

    def recommended_value
      os_value || 'yes'
    end

    def apply
      if @value
        # This is a one-off prep item needed to handle Puppet certs w/FIPS mode
        cmd = %q(puppet config set digest_algorithm sha256)
        puts cmd unless @silent
        %x{#{cmd}}
      else
        say_green 'not using FIPS mode: noop'
        true # we applied nothing, successfully!
      end
    end

    def apply_summary
      "Digest algorithm adjustment for FIPS (as needed) #{@applied_status}"
    end
  end
end
