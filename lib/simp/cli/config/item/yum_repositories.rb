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
      @description = %Q{Sets up the yum repositories for SIMP on apply. (apply-only; noop)}
      @www_yum_dir = File.exists?( '/var/www/yum/') ? '/var/www/yum' : '/srv/www/yum'
      @yum_repos_d = '/etc/yum.repos.d'
      @dir         = "/etc/puppet/environments/simp/hieradata/hosts"
      @yaml_file   = nil
    end
    
    def apply
      result = true

      # set up yum repos
      say_green 'Updating YUM Updates Repositories (NOTE: This may take some time)' if !@silent
      yumpath = File.join( @www_yum_dir,
                           Facter.value('operatingsystem'),
                           Facter.value('operatingsystemrelease'),
                           Facter.value('architecture')
                         )
      begin
        Dir.chdir(yumpath) do
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
        say_green "Finished configuring Updates repository at #{yumpath}/Updates" if !@silent
      rescue YumRepoError, Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES, Errno::EEXIST => err
        say_red "ERROR: Something went wrong setting up the Updates repo in \n#{yumpath}!"
        say_red '       Please make sure your Updates repo is properly configured.'
        say_red "       Error output: #{err.class} - #{err}"
        result = false
      end

      begin
        Dir.chdir( @yum_repos_d ) do
          # disable any CentOS repo spam
          if ! Dir.glob('CentOS*.repo').empty?
            `grep "\\[*\\]" *CentOS*.repo | cut -d "[" -f2 | cut -d "]" -f1 | xargs yum-config-manager --disable`
          end

          # enable 'simp::yum::enable_simp_repos' in hosts/puppet.your.domain.yaml
          if @config_items.fetch('is_master_yum_server').value && !File.exist?('filesystem.repo')
            fqdn    = @config_items.fetch( 'hostname' ).value
            @yaml_file    = File.join( @dir, "#{fqdn}.yaml")

            #FIXME This is exceptionally fragile.  Replace with yaml parsing.
            cmd = %Q{sed -i '/simp::yum::enable_simp_repos : false/ c\\simp::yum::enable_simp_repos : true' #{@yaml_file}}
            puts cmd if !@silent
            %x{#{cmd}}
            # only failures are when yaml file does not exist or can't be accessed
            unless ($?.nil? || $?.success?)
              say_yellow "WARNING: Unable to enable simp::yum::enable_simp_repos in #{@yaml_file}"
              result = false
            end
          end
        end
      rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES => err
        say_red "ERROR: yum configuration failed: #{err.class} - #{err}"
        result = false
      end

      result
    end

    def apply_summary
      "Update to YUM repos and settings in " +
        "#{@yaml_file ? File.basename(@yaml_file) : '<host>.yaml'} #{@applied_status}"
    end
  end
end
