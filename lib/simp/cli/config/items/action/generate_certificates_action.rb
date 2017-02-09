require File.expand_path( '../action_item',  File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::GenerateCertificatesAction < ActionItem
    attr_accessor :dirs
    def initialize
      super
      @key         = 'certificates'
      @description = 'Generate interim certificates for SIMP server'
      @dirs        = {
        :keydist => '/var/simp/environments/simp/site_files/pki_files/files/keydist',
        :fake_ca => ::Utils.puppet_info[:fake_ca_path]
      }
      @die_on_apply_fail = true
      @hostname = nil
    end

    def apply
      # Certificate Management
      @applied_status = :failed
      @hostname = get_item( 'cli::network::hostname' ).value
      debug( "Checking system for '#{@hostname}' certificates" )
      if !(
        File.exist?("#{@dirs[:keydist]}/#{@hostname}/#{@hostname}.pub") &&
        File.exist?("#{@dirs[:keydist]}/#{@hostname}/#{@hostname}.pem")
      )
        debug( "INFO: No certificates were found for '#{@hostname}', generating using FakeCA" )
        result = generate_certificates(@hostname)
        @applied_status = :succeeded if result
      else
        @applied_status = :unnecessary
        @applied_detail = "Certificates already exist in\n    #{@dirs[:keydist]}"
        debug( "INFO: Found existing certificates for '#{@hostname}', not recreating", [:MAGENTA] )
      end
    end

    def apply_summary
      "Interim certificate generation for #{@hostname ? "'#@hostname'" : 'SIMP server'} #{@applied_status}" +
        (@applied_detail ? ":\n    #{@applied_detail}" : '')
    end

    def generate_certificates( hostname )
      result = false
      if Dir.exist?( @dirs[:fake_ca] )
        Dir.chdir( @dirs[:fake_ca] ) do
          File.open('togen', 'w'){|file| file.puts hostname }

          # NOTE: script must exist in ca_dir
          result = execute('./gencerts_nopass.sh auto')

          # blank file so subsequent runs don't re-key our hosts
          File.open('togen', 'w'){ |file| file.truncate(0) }
        end
      else
        error( "\nERROR: Cannot generate certificates for #{hostname}: #{@dirs[:fake_ca]} not found", [:RED] )
      end
      result
    end

  end
end
