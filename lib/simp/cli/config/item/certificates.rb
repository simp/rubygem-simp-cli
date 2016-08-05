require "resolv"
require 'highline/import'
require File.expand_path( '../item',  File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::Certificates < ActionItem
    attr_accessor :dirs
    def initialize
      super
      @key         = 'certificates'
      @description = %Q{Sets up the certificates for SIMP on apply. (apply-only; noop)}
      @dirs        = {
        :keydist => '/etc/puppet/environments/simp/keydist',
        :fake_ca => '/etc/puppet/environments/simp/FakeCA',
      }
      @die_on_apply_fail = true
      @hostname = nil
    end

    def apply
      # Certificate Management
      result = true
      say_green 'Checking system certificates...' if !@silent
      @hostname = @config_items.fetch( 'hostname' ).value
      if !(
        File.exist?("#{@dirs[:keydist]}/#{@hostname}/#{@hostname}.pub") &&
        File.exist?("#{@dirs[:keydist]}/#{@hostname}/#{@hostname}.pem")
      )
        say_green "INFO: No certificates were found for '#{@hostname}, generating..." if !@silent
        result = Simp::Cli::Config::Utils.generate_certificates([@hostname], @dirs[:fake_ca])
      else
        say_green "INFO: Found existing certificates for #{@hostname}, not recreating" if !@silent
      end
      result
    end

    def apply_summary
      "Certificate setup for #{@hostname ? @hostname : 'SIMP'} #{@applied_status}"
    end

  end
end
