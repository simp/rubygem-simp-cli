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
      @description = %q{Prepare and set system to use FIPS mode.

use_fips enforces strict compliance with FIPS-140-2.  All core SIMP modules
can support this configuration. Enabling use_fips here will enable FIPS on
this puppet environment.

IMPORTANT: Be sure you know the security tradeoffs of FIPS-140-2 compliance.
FIPS mode disables the use of MD5 and may require weaker ciphers or key lengths
than your security policies allow.}
     @allow_user_apply = true
     @applied_status = :unattempted
     @digest_algorithm = 'sha256'
    end

    def os_value
      Facter.value('fips_enabled') ? 'yes' : 'no'
    end

    def recommended_value
      os_value || 'yes'
    end

    def apply
      @applied_status = :failed
      if @value
        # This is a one-off prep item needed to handle Puppet certs w/FIPS mode
        cmd = %Q(puppet config set digest_algorithm #{@digest_algorithm})
        puts cmd unless @silent
        %x{#{cmd}}
        @applied_status = :succeeded if $?.success?
      else
        @applied_status = :succeeded
        say_green 'No digest algorithm adjustment necessary since FIPS is not enabled'
      end
    end

    def apply_summary
      case @applied_status
      when :succeeded, :failed, :skipped
        if @value
          return "Digest algorithm adjustment to use #{@digest_algorithm} for FIPS #{@applied_status}"
        else
          return "No digest algorithm adjustment necessary since FIPS is not enabled"
        end
      when :unattempted
        return "Need for digest algorithm adjustment for FIPS not evaluated"
      end
      nil
    end
  end
end
