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
      @description = %Q{Generates certificates for SIMP as needed; action-only.}
      @dirs        = {
        :keydist => "#{::Utils.puppet_info[:simp_environment_path]}/keydist",
        :fake_ca => ::Utils.puppet_info[:fake_ca_path]
      }
      @die_on_apply_fail = true
      @hostname = nil
    end

    def apply
      # Certificate Management
      @applied_status = :failed
      say_green 'Checking system certificates...' if !@silent
      @hostname = @config_items.fetch( 'hostname' ).value
      if !(
        File.exist?("#{@dirs[:keydist]}/#{@hostname}/#{@hostname}.pub") &&
        File.exist?("#{@dirs[:keydist]}/#{@hostname}/#{@hostname}.pem")
      )
        say_green "INFO: No certificates were found for '#{@hostname}, generating..." if !@silent
        result = Simp::Cli::Config::Utils.generate_certificates([@hostname], @dirs[:fake_ca])
        @applied_status = :succeeded if result
      else
        @applied_status = :unnecessary
        @applied_detail = "certificates already exist in #{@dirs[:keydist]}"
        say_magenta "INFO: Found existing certificates for #{@hostname}, not recreating" if !@silent
      end
    end

    def apply_summary
      "FakeCA certificate generation for #{@hostname ? @hostname : 'SIMP'} #{@applied_status}" +
        (@applied_detail ? ":\n\t#{@applied_detail}" : '')
    end

  end
end
