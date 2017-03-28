require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SvckillMode < Item
    def initialize
      super
      @key         = 'svckill::mode'
      @description = %Q{Strategy svckill should use when it encounters undeclared services

'enforcing' = Shut down and disable all services not listed in your
              manifests or the exclusion file
'warning'   = Only report what undeclared services should be shut
              down and disabled, without actually making the changes
              to the system

NOTICE: svckill is the mechanism that SIMP uses to comply with the
requirement that no unauthorized services are running on your system.
Is it HIGHLY recommended that you set this to 'enforcing'. Please be
aware that, if you do this, svckill will stop ALL services that are
not referenced in your Puppet configuration.}

      @warning_msgs = {
        :enforcing => %Q{IMPORTANT:  Be sure to register your site-specific services with svckill
to prevent them from being automatically shut down and disabled.
See svckill::ignore and svckill::ignore_files.},

        :warning => %Q{IMPORTANT: 'warning' will allow you to ascertain the list of undeclared
services running on your system.  However, to ensure no unnecessary
services are running, you must register these services with svckill
and then change #{@key} to 'enforcing'.  See svckill::ignore and
svckill::ignore_files.}
      }
    end

    def recommended_value
      # We recommend 'warning' instead of 'enforcing', because 'warning' is not 
      # destructive, should the user fail to declare their services. Issuing a
      # 'warning' gives the user time to figure out what services they need to
      # declare, without rendering their system unusable.
      'warning'
    end

    def validate( x )
      result = false
      if x == 'warning'
        result = true
        info( @warning_msgs[:warning], [:RED] )
        pause(:info)
      elsif x == 'enforcing' 
        result = true
        info( @warning_msgs[:enforcing], [:RED] )
        pause(:info)
      end
      result
    end

    def not_valid_message
      'Must be "enforcing" or "warning"'
    end
  end
end
