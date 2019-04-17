require_relative '../action_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SetPuppetDigestAlgorithmAction < ActionItem

    def initialize
      super
      @key              = 'fips_digest'
      @description      = 'Set Puppet digest algorithm to work with FIPS'
      @category         = :puppet_global
      @applied_status   = :unattempted
      @digest_algorithm = 'sha256'
    end

    def apply
      @applied_status = :failed
      # This is a one-off prep item needed to ensure any `puppet apply's` used
      # in configuration prior to setting up Puppet config (which also sets
      # the digest algorithm to sha256) use the correct digest algorithm.
      result = execute( %Q(puppet config set digest_algorithm #{@digest_algorithm}) )
      @applied_status = :succeeded if result
    end

    def apply_summary
      return "Setting of Puppet digest algorithm to #{@digest_algorithm} for FIPS #{@applied_status}"
    end
  end
end
