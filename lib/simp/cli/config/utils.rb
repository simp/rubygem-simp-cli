module Simp; end
class Simp::Cli; end
module Simp::Cli::Config; end

class Simp::Cli::Config::Utils

  ###################################################################
  # Let's be DRY.  Before adding methods to this file, first see if
  # Simp::Cli::Utils has what you need.
  ###################################################################

  class << self

    def validate_fqdn fqdn
      # matches Simplib::Hostname custom type from pupmod-simp-simplib
      regex = %r{^(?i-mx:(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]{2}|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])\.?)$}
      ((fqdn =~ regex) ? true : false )
    end


    def validate_ip ip
      # using the native 'resolv' class in order to minimize non-EL rubygems
      # snarfed from:
      # http://stackoverflow.com/questions/3634998/how-do-i-check-whether-a-value-in-a-string-is-an-ip-address
      require 'resolv'
      ((ip =~ Resolv::IPv4::Regex) || (ip =~ Resolv::IPv6::Regex)) ? true : false
    end


    def validate_hostname hostname
      # based on:
      #   http://stackoverflow.com/questions/2532053/validate-a-hostname-string
      #
      # nicer solution that only works on ruby1.9+:
      #   ( hostname =~  %r{\A(?!-)[a-z0-9-]{1,63}(?<!-)\Z} ) ? true : false
      #
      # ruby1.8-safe version:
      (( hostname =~  %r{\A[a-z0-9-]{1,63}\Z} ) ? true : false ) &&
       (( hostname !~ %r{^-|-$} ) ? true : false )
    end


    def validate_netmask( x )
      # a brute-force regexp that validates all possible valid netmasks
      nums = '(128|192|224|240|248|252|254)'
      znums = '(0|128|192|224|240|248|252|254)'
      regex = /^((#{nums}\.0\.0\.0)|(255\.#{znums}\.0\.0)|(255\.255\.#{znums}\.0)|(255\.255\.255\.#{znums})|(255\.255\.255\.255))$/i
      x =~ regex ? true: false
    end


    def validate_hiera_lookup( x )
      x.to_s.strip =~ %r@\%\{.+\}@ ? true : false
    end


    # pure-ruby openldap hash generator
    def encrypt_openldap_hash( string, salt=nil )
       require 'digest/sha1'
       require 'base64'

       # Ruby 1.8.7 hack to do Random.new.bytes(4):
       salt   = salt || (x = ''; 4.times{ x += ((rand * 255).floor.chr ) }; x)
       salt.force_encoding('UTF-8') if salt.encoding.name == 'ASCII-8BIT'

       digest = Digest::SHA1.digest( string + salt )

       # NOTE: Digest::SHA1.digest in Ruby 1.9+ returns a String encoding in
       #       ASCII-8BIT, whereas all other Strings in play are UTF-8
       digest.force_encoding('UTF-8') if digest.encoding.name == 'ASCII-8BIT'

       "{SSHA}"+Base64.encode64( digest + salt ).chomp
    end


    def validate_openldap_hash( x )
      (x =~ %r@\{SSHA\}[A-Za-z0-9=+/]+@ ) ? true : false
    end

    # Check the supplied password against the given hash.
    # return true upon match
    def check_openldap_password(password, ssha)
      require 'base64'
      decoded = Base64.decode64(ssha.gsub(/^{SSHA}/, ''))
      hash = decoded[0..19]
      salt = decoded[20..-1]
      encrypt_openldap_hash(password, salt) == ssha
    end
  end
end
