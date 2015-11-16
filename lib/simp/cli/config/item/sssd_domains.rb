require 'highline/import'
require 'puppet'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SssdDomains < ListItem
    def initialize
      super
      @key         = 'sssd::domains'
      @description = %Q{
        A list of domains for SSSD to use.
        `simp config` will automativcally populate this field with `FQDN` if
        `use_fqdn` is true, otherwise it will comment out the field.
      }.gsub(/^\s+/, '' )
    end


    def validate_item( x )
      x =~ /[-a-z]/i ? true : false
    end

    def query_ask
      use_ldap   = @config_items.fetch( 'use_ldap' ).value
      if use_ldap
        @value = ['LDAP']
      else
        @skip_yaml = true
        @value = []
      end
    end
  end
end
