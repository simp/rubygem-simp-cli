require File.expand_path( '../action_item',  File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::GenerateCertificatesAction < ActionItem
    attr_accessor :dirs, :group
    def initialize
      super
      @key               = 'certificates'
      @description       = 'Generate interim certificates for SIMP server'
      @dirs              = {
        :keydist    => '/var/simp/environments/simp/site_files/pki_files/files/keydist',
        :fake_ca    => ::Utils.puppet_info[:fake_ca_path]
      }
      @group             = ::Utils.puppet_info[:puppet_group]
      @die_on_apply_fail = true
      @hostname          = nil
    end

    def apply
      # Certificate Management
      @applied_status = :failed
      @hostname = get_item( 'cli::network::hostname' ).value
      debug( "Checking system for '#{@hostname}' certificates" )
      setup_directories unless File.exist?(@dirs[:keydist])
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

          # Script generates appropriate dirs/files in keydist/ and
          # locks down their permissions to allow the puppet group.
          #
          # NOTE:  The script only sets ownership and permissions for
          # keydist/ and below. It leaves the parent directories of
          # keydist/ unchanged.
          result = execute('./gencerts_nopass.sh auto')

          # blank file so subsequent runs don't re-key our hosts
          File.open('togen', 'w'){ |file| file.truncate(0) }
        end
      else
        error( "\nERROR: Cannot generate certificates for #{hostname}: #{@dirs[:fake_ca]} not found", [:RED] )
      end
      result
    end

    def setup_directories
      # Shouldn't get here if simp-environment RPM >= 6.2.8 has been
      # installed. However, if this is an R10k-based installation and
      # the user did not set up the pki_files tree, create it here to
      # ensure the permissions are set up appropriately.
      FileUtils.mkdir_p(@dirs[:keydist])
      site_files_dir = File.expand_path(File.join(@dirs[:keydist], '..', '..', '..'))

      # open up read permissions of the SIMP-specific parent
      # directories of /var/simp/environments/simp/site_files, to
      # ensure site_files/ can be accessed by the puppet group
      prev = site_files_dir
      (1..3).each do |iter|
        # relative logic allows this code to be unit tested
        current = File.dirname(prev)
        FileUtils.chmod(0755, current)
        prev = current
      end

      # lock down ownership and permissions of the site_files tree
      # to only the puppet group
      begin
        FileUtils.chown_R(nil, @group, site_files_dir)
      rescue Errno::EPERM, ArgumentError => e
        # This will happen if the user is not root or the group does
        # not exist.
        err_msg = "Could not recursively change #{site_files_dir} group to '#{@group}': #{e}"
        raise ApplyError.new(err_msg)
      end
      FileUtils.chmod_R('g+rX,o-rwx', site_files_dir)
    end

  end
end
