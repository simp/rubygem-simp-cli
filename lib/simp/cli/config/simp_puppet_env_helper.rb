require 'simp/cli/defaults'
require 'simp/cli/environment/omni_env_controller'
require 'simp/cli/logging'
require 'simp/cli/utils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config; end

# Class to encapsulate the nuances unique to a SIMP Puppet environment
class Simp::Cli::Config::SimpPuppetEnvHelper

  include Simp::Cli::Logging

  # +env_name+: Puppet environment name
  # +start_time+: Start time of the process using this object.
  #   Used to ensure all file backup operations can be linked
  #   together.
  #
  def initialize(env_name, start_time = Time.now)
    @env_name = env_name
    @env_info = nil
    @start_time = start_time
  end

  # Creates a new SIMP omni environment
  # @returns Hash of environment information for the created environment.
  def create
    # Workaround an issue in which the example, empty production Puppet
    # environment that is installed by the puppet-agent RPM causes the
    # OmniEnvController#create to fail.
    if Dir.exist?(env_info[:puppet_env_dir])
      back_up_puppet_environment(env_info[:puppet_env_dir])
    end

    #TODO read much of this config in from a config file
    omni_options = Simp::Cli::Utils.default_simp_env_config
    omni_options[:types][:puppet].merge! ({
      strategy: :skeleton,
      puppetfile_generate: true,
      puppetfile_install: true,
    })
    omni_options[:types][:secondary][:strategy] = :skeleton
    omni_options[:types][:writable][:strategy]  = :skeleton # noop

    #TODO make sure it matches latest OmniEnvController code
    omni_controller = Simp::Cli::Environment::OmniEnvController.new(omni_options, @env_name)
    omni_controller.create

    # update @env_info to reflect the actual Puppet environment, as some
    # configuration may have changed (e.g., module path)
    @env_info = get_current_env_info
    @env_info
  end

  def env_info
    return @env_info if @env_info

   # First time this is set, we don't know if @env_name environment
   # exists yet. However, the info derived from general Puppet
   # configuration will at least contain the correct paths to the 3
   # SIMP omni environment directories. This is sufficient for status
   # queries and creation of the environment.  We'll update @env_info
   # in create(), after the environment is created, to ensure all the
   # settings for the environment are correct (e.g. module path and
   # Hieradata dir).
   @env_info = get_current_env_info
  end

  # @returns [status_code, status_detail_msg] of the SIMP
  #          omni-environment, as it applies to 'simp config' operation
  #
  # Status Codes:
  # :exists    - Valid Puppet & secondary environments exist
  #              (minimal validation)
  # :invalid   - Invalid Puppet and/or secondary environments exist
  # :creatable - Valid Puppet & secondary environments can be safely
  #              created, overwriting any existing skeletal environment
  def env_status
    #TODO integrate the (yet to be written) OmniEnvController environment
    #     status method
    #
    status_puppet, details_puppet = puppet_env_status
    status_secondary, details_secondary  = secondary_env_status

    # Status mapping:
    #
    # |puppet  sec| :missing   | :present | :invalid |
    # ------------------------------------------------
    # |:missing   | :creatable | :invalid | :invalid |
    # |:empty     | :creatable | :invalid | :invalid |
    # |:present   | :invalid   | :exists  | :invalid |
    # |:invalid   | :invalid   | :invalid | :invalid |
    #

    status_code = nil
    status_msg = nil
    if (status_puppet == :present) && (status_secondary == :present)
      status_code = :exists
    elsif (status_secondary == :missing) &&
          ( (status_puppet == :empty) || (status_puppet == :missing) )
      status_code = :creatable
    else
      status_code = :invalid
    end

    status_msg = [ details_puppet, details_secondary ].join("\n")
    [ status_code, status_msg ]
  end

  # @returns Puppet environment [status_code, status_message]
  #
  # STATUS CODE
  # :missing - Environment does not exist
  # :empty   - Environment does exist but does not have any modules
  #            in its environment path.  This is **ASSUMED** to be
  #            a skeleton directory that can be overwritten, such
  #            as the production env directory installed by the
  #            puppet-agent package.
  # :present - Environment exists, contains modules in its module
  #            path, and has a stock SIMP hieradata directory (i.e.,
  #            top-level 'data' or 'hieradata' dir in the env dir)
  # :invalid - Environment exists, contains modules in its module
  #            path, but does not have a stock SIMP hieradata directory
  #
  def puppet_env_status
   unless Dir.exist?(env_info[:puppet_env_dir])
     return [:missing, "Puppet environment '#{@env_name}' does not exist"]
   end

   module_paths = env_info[:puppet_config]['modulepath'].dup
   module_paths = module_paths.nil? ? [] : module_paths.split(':')

   # Paths containing PE modules will be added on PE systems, so we need to
   # remove them from the paths we check for existing modules
   if env_info[:is_pe]
     module_paths.delete_if { |path| path.start_with?('/opt/puppetlabs') }
   end

   modules_found = false
   modules_found_path = []

   module_paths.each do |path|
    metadata_files = Dir.glob(File.join(path, '*','metadata.json'))
    unless metadata_files.empty?
      modules_found = true
      modules_found_path << File.dirname(path)
      break
    end
   end

   unless modules_found
     return [:empty, "Existing Puppet environment '#{@env_name}' contains no modules" ]
   end

   if env_info[:puppet_env_datadir].nil?
     status = :invalid
     msg = "Existing Puppet environment '#{@env_name}' at '#{env_info[:puppet_env_dir]}' missing 'data' or 'hieradata' dir"
   else
     status = :present
     msg = "Puppet environment '#{@env_name}' exists with modules at '#{modules_found_path.join(':')}'"
   end
   [ status, msg ]
  end

  # @returns secondary environment [status_code, status_message]
  #
  # STATUS CODE
  # :missing - Environment does not exist
  # :present - Environment exists and contains the executable certificate
  #            generator script
  # :invalid - Environment exists, but does not contain the executable
  #            certificate generator script
  #
  # FIXME?: We don't check for the presence of the 'site_files'
  # sub-directory, because Simp::Cli::Config::Item::GenerateCertificatesAction
  # will create it when it generates FakeCA-based certificates. Should we
  # expect that dir to exist?
  #
  def secondary_env_status
   unless Dir.exist?(env_info[:secondary_env_dir])
     return [:missing, "Secondary environment '#{@env_name}' does not exist at '#{env_info[:secondary_env_dir]}'"]
   end

   cert_gen = File.join(env_info[:secondary_env_dir], 'FakeCA',
     Simp::Cli::CERTIFICATE_GENERATOR)

   if File.executable?(cert_gen)
     status = :present
     msg = "Secondary environment '#{@env_name}' exists at '#{env_info[:secondary_env_dir]}'"
   else
     status = :invalid
     msg = "Existing secondary environment '#{@env_name}' missing executable #{cert_gen}"
   end

   [ status, msg ]
  end

private
  # Back up a Puppet environment outside of the environments directory,
  # so that this backup is not accidentally purged by a R10K/CodeManager
  # deploy operation.
  #
  # +puppet_env_dir+: fully qualified path of the Puppet environment
  #   to be backed up
  def back_up_puppet_environment(puppet_env_dir)
    return unless Dir.exist?(puppet_env_dir)

    # create the backup environments dir
    env_parent_dir = File.dirname(puppet_env_dir)
    backup_dir = "#{env_parent_dir}.bak"
    FileUtils.mkdir_p(backup_dir)

    # ensure the ownership is correct
    orig_dir_stat = File.stat(env_parent_dir)
    File.chown(orig_dir_stat.uid, orig_dir_stat.gid, backup_dir)
    File.chmod(orig_dir_stat.mode & 0777, backup_dir)

    # move the environment to a timestamped dir in the backup dir
    backup = File.join(backup_dir,
      "#{File.basename(puppet_env_dir)}.#{Simp::Cli::Utils::timestamp_compact(@start_time)}"
    )
    logger.debug( "Backing up #{puppet_env_dir} to #{backup}" )
    FileUtils.mv(puppet_env_dir, backup)
  end

  # @returns Hash of Puppet environment information with the following keys
  #
  # :puppet_config      = Puppet master configuration for the environment
  # :puppet_group       = Puppet group
  # :puppet_version     = Version of Puppet
  # :puppet_env         = Name of the SIMP Puppet environment
  # :puppet_env_dir     = SIMP Puppet environment directory
  # :puppet_env_datadir = SIMP Puppet environment hieradata directory
  # :secondary_env_dir  = SIMP secondary environment
  # :writable_env_dir   = SIMP writable environment
  # :is_pe              = Set if the system is Puppet Enterprise
  #
  def get_current_env_info
    puppet_info = get_system_puppet_info
    puppet_env_dir = File.join(puppet_info[:environment_path], @env_name)
    secondary_env_dir = File.join(puppet_info[:secondary_environment_path], @env_name)
    writable_env_dir = File.join(puppet_info[:writable_environment_path], @env_name)

    {
     :puppet_config      => puppet_info[:config],
     :puppet_group       => puppet_info[:puppet_group],
     :puppet_version     => puppet_info[:version],
     :puppet_env         => @env_name,
     :puppet_env_dir     => puppet_env_dir,
     :puppet_env_datadir => get_puppet_env_datadir(puppet_env_dir),
     :secondary_env_dir  => secondary_env_dir,
     :writable_env_dir   => writable_env_dir,
     :is_pe              => puppet_info[:is_pe]
    }
  end

  # Determine the basename of the hieradata directory in env_path
  #
  # +env_path+:  Puppet environment path
  #
  # This (weak) check does **not** attempt to extract this information
  # from the contents of global and/or environment-specific hiera.yaml
  # files, but looks for one of the two stock SIMP configurations for
  # hieradata.
  def get_puppet_env_datadir(env_path)
    env_datadir = nil
    env_hiera5_file = File.join(env_path, 'hiera.yaml')
    env_hiera5_dir = File.join(env_path, 'data')
    env_hiera3_dir = File.join(env_path, 'hieradata')
    if File.exist?(env_hiera5_file)
      # Using environment-specific Hiera 5 configuration
      if Dir.exist?(env_hiera5_dir)
        # The data directory SIMP uses for Hiera 5 is in place, so we are
        # ASSUMING this is a stock SIMP configuration.
        env_datadir = env_hiera5_dir
      end
    elsif Dir.exist?(env_hiera3_dir)
      env_datadir = env_hiera3_dir
    end

    env_datadir
  end

  def get_system_puppet_info
    Simp::Cli::Utils::PuppetInfo.new(@env_name).system_puppet_info
  end

end

