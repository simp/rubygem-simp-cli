require_relative '../item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SvckillMode < Item
    def initialize
      super
      @key         = 'svckill::mode'
      @description = %Q{Strategy svckill should use when it encounters undeclared services.

'enforcing' = Shut down and disable all services not listed in your
              manifests or the exclusion file
'warning'   = Only report what undeclared services should be shut
              down and disabled, without actually making the changes
              to the system

NOTICE: svckill is the mechanism that SIMP uses to comply with the
requirement that no unauthorized services are running on your system.
If you are fully aware of all services that need to be running on the
system, including any custom applications, use 'enforcing'.  If you
first need to ascertain which services should be running on the system,
use 'warning'.}

      @warning_msgs = {
        :enforcing =>
%Q{IMPORTANT:  Be sure to register your site-specific services with
svckill to prevent them from being automatically shut down and disabled.
See svckill::ignore and svckill::ignore_files.},

        :warning =>
%Q{IMPORTANT: Once you have examined the list of undeclared services
reported by svckill and have determined which of those should be
allowed, register the allowed services with svckill and then change
#{@key} to 'enforcing'.  See svckill::ignore and svckill::ignore_files.}
      }
    end

    def get_recommended_value
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
        info( @warning_msgs[:warning], [:YELLOW] )

        # if the value is not pre-assigned, pause to give the user time
        # to think about the impact of not specifying NTP servers
        pause(:info) if @value.nil?
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
