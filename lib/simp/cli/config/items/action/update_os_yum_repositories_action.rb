require 'simp/cli/config/items/action_item'
require 'simp/cli/config/items/data/cli_network_hostname'

module Simp::Cli::Config
  class Item::UpdateOsYumRepositoriesAction < ActionItem
    class YumRepoError < RuntimeError; end

    attr_accessor :www_yum_dir, :yum_repos_d
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key              = 'yum::repositories::update'
      @description      = 'Set up local YUM repositories for SIMP'
      @category         = :system
      @www_yum_dir      = '/var/www/yum/'
      @yumpath          = nil
      @yum_repos_d      = '/etc/yum.repos.d'
      @yum_update       = :unattempted
      @yum_repo_disable = :unattempted
    end

    def apply
      @applied_status = :failed
      @yum_update = :failed

      # set up yum repos
      @yumpath = File.join( @www_yum_dir,
                           Facter.value('operatingsystem'),
                           Facter.value('operatingsystemrelease'),
                           Facter.value('architecture')
                         )
      info( "Updating YUM Updates repository at #{File.join(@yumpath, 'Updates')}" )
      begin
        Dir.chdir(@yumpath) do
          FileUtils.mkdir('Updates') unless File.directory?('Updates')
          Dir.chdir('Updates') do
            execute( %q(find .. -type f -name '*.rpm' -exec ln -sf {} \\;) )
            cmd = 'createrepo -q -p --update .'
            result = Simp::Cli::Utils::show_wait_spinner {
              execute(cmd)
            }
            raise YumRepoError.new("'#{cmd}' failed in #{Dir.pwd}") unless result
          end
        end
        result = execute("chown -R root:apache #{@www_yum_dir}/")
        result = result && execute("chmod -R u=rwX,g=rX,o-rwx #{@www_yum_dir}/")
        raise YumRepoError.new("Updating ownership and permissions of #{@www_yum_dir}/ failed!")  unless result
        @yum_update = :succeeded
        info( 'Finished updating Updates repository' )
      rescue YumRepoError, Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES, Errno::EEXIST => err
        error( "\nERROR: Something went wrong setting up the Updates repo in #{@yumpath}!", [:RED] )
        error( '       Please make sure your Updates repo is properly configured.', [:RED] )
        error( "       Error output: #{err.class} - #{err}", [:RED] )
      end

      @yum_repo_disable = :failed
      begin
        Dir.chdir( @yum_repos_d ) do
          # disable any CentOS repo spam
          if ! Dir.glob('CentOS*.repo').empty?
            info( "Disabling CentOS repositories in #{@yum_repos_d}" )
            # Don't use pipes with spawn
            repos = run_command(%q{grep "\\[*\\]" *CentOS*.repo})[:stdout].strip.split("\n")
            repos.map { |repo|
              next if not repo =~ /:\[.*\]$/
              repo.split(':[').last.tr(']','')}.each do |repo_name|
                execute("yum-config-manager --disable #{repo_name}") if not repo_name.nil?
            end
            info( 'Finished disabling CentOS repositories' )
          end
        end
        @yum_repo_disable = :succeeded
      rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES => err
        error( "\nERROR: Disabling of CentOS repositories failed: #{err.class} - #{err}", [:RED] )
      end
      @applied_status = :succeeded if (@yum_update == :succeeded) and (@yum_repo_disable == :succeeded)
    end

    def apply_summary
      return "Setup of local system (OS) YUM repositories for SIMP #{@applied_status}"
    end
  end
end
