require 'resolv'
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::YumRepositories < ActionItem
    class YumRepoError < RuntimeError; end

    attr_accessor :www_yum_dir, :yum_repos_d, :dir
    def initialize
      super
      @key         = 'yum::repositories'
      @description = %Q{Sets up the yum repositories for SIMP; action-only.}
      @www_yum_dir = File.exists?( '/var/www/yum/') ? '/var/www/yum' : '/srv/www/yum'
      @yumpath     = nil
      @yum_repos_d = '/etc/yum.repos.d'
      @dir         = "#{::Utils.puppet_info[:simp_environment_path]}/hieradata/hosts"
      @yaml_file   = nil

      @yum_update  = :unattempted # action that is always done
      @yaml_update = :unattempted # action that is optionally done
    end

    def apply
      @applied_status = :failed
      @yum_update = :failed

      # set up yum repos
      say_green 'Updating YUM Updates Repositories (NOTE: This may take some time)' if !@silent
      @yumpath = File.join( @www_yum_dir,
                           Facter.value('operatingsystem'),
                           Facter.value('operatingsystemrelease'),
                           Facter.value('architecture')
                         )
      begin
        Dir.chdir(@yumpath) do
          FileUtils.mkdir('Updates') unless File.directory?('Updates')
          Dir.chdir('Updates') do
            system( %q(find .. -type f -name '*.rpm' -exec ln -sf {} \\;) )
            cmd = 'createrepo -qqq -p --update .'
            if @silent
              cmd << ' &> /dev/null'
            else
              puts cmd
            end
            system(cmd)
            raise YumRepoError "'#{cmd}' failed in #{Dir.pwd}" unless ($?.nil? || $?.success?)
          end
        end
        system("chown -R root:apache #{@www_yum_dir}/ #{ '&> /dev/null' if @silent }")
        system("chmod -R u=rwX,g=rX,o-rwx #{@www_yum_dir}/")
        raise YumRepoError, "chmod -R u=rwX,g=rX,o-rwx #{@www_yum_dir}/ failed!"  unless ($?.nil? || $?.success?)
        @yum_update = :succeeded
        say_green "Finished configuring Updates repository at #{@yumpath}/Updates" if !@silent
      rescue YumRepoError, Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES, Errno::EEXIST => err
        say_red "ERROR: Something went wrong setting up the Updates repo in #{@yumpath}!"
        say_red '       Please make sure your Updates repo is properly configured.'
        say_red "       Error output: #{err.class} - #{err}"
      end

      fqdn    = @config_items.fetch( 'hostname' ).value
      @yaml_file    = File.join( @dir, "#{fqdn}.yaml")
      begin
        Dir.chdir( @yum_repos_d ) do
          # disable any CentOS repo spam
          if ! Dir.glob('CentOS*.repo').empty?
            `grep "\\[*\\]" *CentOS*.repo | cut -d "[" -f2 | cut -d "]" -f1 | xargs yum-config-manager --disable`
          end

          # enable 'simp::yum::enable_simp_repos' in hosts/puppet.your.domain.yaml
          if @config_items.fetch('is_master_yum_server').value && !File.exist?('filesystem.repo')
            @yaml_update = :failed
            #FIXME This is fragile.  Replace with yaml parsing.
            cmd = %Q{sed -i 's/^simp::yum::enable_simp_repos\s*:\s*false/simp::yum::enable_simp_repos : true/' #{@yaml_file}}
            puts cmd if !@silent
            %x{#{cmd}}
            # only failures are when yaml file does not exist or can't be accessed
            if ($?.nil? || $?.success?)
              @yaml_update = :succeeded
            else
              say_red "ERROR: Unable to enable simp::yum::enable_simp_repos in #{@yaml_file}"
            end
          else
            @yaml_update = :unnecessary
          end
        end
      rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES => err
        say_red "ERROR: yum configuration failed: #{err.class} - #{err}"
        @yaml_update = :failed
      end
      @applied_status = :succeeded if (@yum_update == :succeeded) and (@yaml_update != :failed)
    end

    def apply_summary
      if (@applied_status == :skipped or @applied_status == :unattempted)
        return "YUM Update repo configuration and update to simp::yum::enable_simp_repos in <host>.yaml #{@applied_status}"
      else
        yumrepo_msg = "Configuration of YUM Update repo at #{@yumpath} #{@yum_update}"
        if @yaml_update == :unnecessary
          return yumrepo_msg
        else
          yaml_file = @yaml_file.nil? ? '<host>.yaml' :  File.basename(@yaml_file)
          return yumrepo_msg + "\nUpdate to simp::yum::enable_simp_repos" +
           " in #{yaml_file} #{@yaml_update}"
        end
      end
    end
  end
end
