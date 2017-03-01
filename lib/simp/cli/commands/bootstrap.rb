module Simp::Cli::Commands; end

require 'simp/cli/config/items/action/set_production_to_simp_action'
require 'highline/import'
require 'highline'

class Simp::Cli::Commands::Bootstrap < Simp::Cli
  require 'pty'
  require 'timeout'
  require 'facter'
  require File.expand_path( '../defaults', File.dirname(__FILE__) )
  require File.expand_path( '../lib/track_output', File.dirname(__FILE__) )
  BOOTSTRAP_LOG = File.join(SIMP_CLI_HOME, "simp_bootstrap.log.#{Time.now.strftime('%Y%m%dT%H%M%S')}.log")
  HighLine.colorize_strings

  @verbose = false
  @track = true
  @unsafe = false
  @opt_parser = OptionParser.new do |opts|
    opts.banner = "\n=== The SIMP Bootstrap Tool ==="
    opts.separator "\nThe SIMP Bootstrap Tool aids initial configuration of the system by"
    opts.separator "bootstrapping it. This should be run after 'simp config' has applied a new"
    opts.separator "system configuration.\n\n"
    opts.separator "The tool configures and starts a puppetserver with minimal memory, on port"
    opts.separator "8150.  It then applies the simp and pupmod modules to the system which,"
    opts.separator "among other things, will configure the puppetserver service according to"
    opts.separator "the system configuration (values set in simp config).  Two tagless puppet runs"
    opts.separator "follow, to apply all other core modules.\n\n"
    opts.separator "By default, this tool will prompt to keep or remove existing puppetserver"
    opts.separator "certificates. To skip the prompt, see OPTIONS.\n\n"
    opts.separator "This utility can be run more than once, but is it not recommended."
    opts.separator "Note what options are available before re-running.\n\n"
    opts.separator "Logging information about the run is written to #{SIMP_CLI_HOME}/simp_bootstrap_*.log\n\n"
    opts.separator "OPTIONS:\n"

    opts.on("-v", "--[no-]verbose", "Enables/disables verbose mode. Prints out verbose information.") do |v|
      @verbose = v
    end

    opts.on("-r", "--[no-]remove_certs", "Remove the existing puppetserver certificates. Default is KEEP.") do |r|
      @remove_certs = r
    end

    opts.on("-t", "--[no-]track", "Enables/disables the tracker. Default is enabled.") do |t|
      @track = t
    end

    opts.on("-u", "--unsafe", "Run bootstrap in 'unsafe' mode.  Interrupts are NOT captured and ignored. Default is SAFE.") do |u|
      @unsafe = u
    end

    opts.on("-h", "--help", "Print out this message.") do
      puts opts
      @help_requested = true
    end

  end

  def self.run(args = [])
    super
    return if @help_requested

    # During simp config, critical failed items are logged in a lock file. If the file
    # exists, don't bootstrap.
    if File.exist?(Simp::Cli::BOOTSTRAP_START_LOCK_FILE)
      fail("Bootstrap cannot proceed until problem identified in\n" +
        "#{Simp::Cli::BOOTSTRAP_START_LOCK_FILE} is solved and that file is removed.")
    end

    bootstrap_start_time = Time.now

    # Set us up to use the SIMP environment, if this has not already been done.
    # (1) Be careful to preserve the existing primary, 'production' environment,
    #     if one exists.
    # (2) Create links to production in both the primary and secondary environment
    #     paths.
    environment_path = ::Utils.puppet_info[:simp_environment_path]
    fail("Could not find the simp environment path at #{environment_path}") unless File.directory?(environment_path)

    item = Simp::Cli::Config::Item::SetProductionToSimpAction.new
    item.start_time = bootstrap_start_time
    item.apply
    fail ("Could not set 'simp' to production environment") unless item.applied_status == :succeeded

    linecounts = Array.new

    # Open log file
    logfilepath = File.expand_path(BOOTSTRAP_LOG)
    FileUtils.mkpath(File.dirname(logfilepath)) unless File.exists?(logfilepath)
    @logfile = File.open(logfilepath, 'w')

    # Print intro
    system('clear')
    say ("<%= color('=== Starting SIMP Bootstrap ===', :yellow) %>")

    # Set an interrupt trap if safe mode is enabled
    say "> The log can be found at '#{@logfile.path}'\n"
    if not @unsafe
      Signal.trap("INT") { say "<%= color('Safe mode enabled, ignoring interrupt', :magenta) %>"}
      say "> INFO: SAFE mode enabled" if @verbose
    else
      say "> INFO: SAFE mode disabled" if @verbose
    end


    # Kill all puppet processes and stop specific services
    say "> <%= color('Killing all Puppet processes', :cyan) %>"
    system("pkill -9 -f puppet >& /dev/null")
    system('pkill -f pserver_tmp')
    system("puppet resource service puppetserver ensure=stopped >& /dev/null")

    # Kill the connection with puppetdb
    say "> <%= color('Killing connection to PuppetDB', :cyan) %>"
    system("puppet resource service puppetdb ensure=stopped >& /dev/null")
    confdir = ::Utils.puppet_info[:config]['confdir']
    if File.exists?("#{confdir}/routes.yaml")
      system("rm -f #{confdir}/routes.yaml")
      say "> INFO: <%= color('Successfully removed #{confdir}/routes.yaml', :green) %>" if @verbose
    else
      say "> INFO: Did not find #{confdir}/routes.yaml, not removing" if @verbose
    end
    system('puppet config set --section master storeconfigs false')
    system('puppet config set --section main storeconfigs false')
    say "> INFO: <%= color('Successfully set storeconfigs=false in #{confdir}/puppet.conf', :green) %>" if @verbose

    # Figure out what to do with puppetserer certs
    rm_certs = false
    if @remove_certs then
      rm_certs = true
    # If remove_certs is not true OR false, it is nil and should be prompted for.
    elsif not @remove_certs == false
      rm_ask = ask("> Do you wish to keep existing puppetserver certificates? (yes|no) ") { |q| q.validate = /(yes)|(no)/i }
      rm_certs = true if rm_ask == 'no'
    end
    ssldir = ::Utils.puppet_info[:config]['ssldir']
    if rm_certs
      FileUtils.rm_rf(Dir.glob(File.join(ssldir,'*')))
      say "> <%= color('Successfully removed #{ssldir}/*', :green) %>"
    else
      say "> Keeping current puppetserver certificates, in #{ssldir}"
    end

    # Remove the run directory
    rundir = ::Utils.puppet_info[:config]['rundir']
    FileUtils.rm_f(Dir.glob(File.join(rundir,'*')))
    say "> <%= color('Successfully removed #{rundir}/*', :green) %>"

    # Get the puppetserver configured to listen on port 8150.
    say "> <%=color('Configuring puppetserver to listen on port 8150', :cyan) %>"
    begin

      # Back everything up.
      puppetserver_dir = '/etc/puppetlabs/puppetserver/conf.d'
      if File.directory?(puppetserver_dir)
        conf_files = ["#{puppetserver_dir}/webserver.conf", "#{puppetserver_dir}/web-routes.conf", '/etc/sysconfig/puppetserver']
        conf_files.each do |f|
          if File.exists?(f)
            system(%{cp #{f} #{f}.BAK})
            say "> <%= color('Sucessfully backed up #{f} to #{f}.BAK', :green) %>"
          end
        end
      else
        fail( "Could not find directory #{puppetserver_dir}" )
      end

      # Run in a temporary cache space.
      server_conf_tmp = "#{::Utils.puppet_info[:config]['vardir']}/pserver_tmp"
      FileUtils.mkdir_p(server_conf_tmp)
      FileUtils.chown('puppet','puppet',server_conf_tmp)
      system(%{puppet resource simp_file_line puppetserver path='/etc/sysconfig/puppetserver' match='^JAVA_ARGS' line='JAVA_ARGS="-Xms2g -Xmx2g -XX:MaxPermSize=256m -Djava.io.tmpdir=#{server_conf_tmp}"' 2>&1 > /dev/null})
      say "> <%= color('Sucessfully wrote java tmpdir to /etc/sysconfig/puppetserver', :green) %>"

      # Slap minimalistic conf files in place to get puppetserver off of the ground.
      system(%{cat > #{puppetserver_dir}/webserver.conf <<-EOM
webserver: {
    access-log-config: /etc/puppetlabs/puppetserver/request-logging.xml
    client-auth: want
    ssl-host = 0.0.0.0
    ssl-port = 8150
}
EOM
})
      say "> <%= color('Sucessfully wrote webserver.conf to #{puppetserver_dir}/webserver.conf', :green) %>"
      system(%{cat > #{puppetserver_dir}/web-routes.conf <<-EOM
web-router-service: {
    "puppetlabs.services.ca.certificate-authority-service/certificate-authority-service": "/puppet-ca"
    "puppetlabs.services.master.master-service/master-service": "/puppet"
    "puppetlabs.services.legacy-routes.legacy-routes-service/legacy-routes-service": ""
    "puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service": "/puppet-admin-api"
    "puppetlabs.trapperkeeper.services.status.status-service/status-service": "/status"
}
EOM
})
      say "> <%= color('Sucessfully wrote web-routes.conf to #{puppetserver_dir}/web-routes.conf', :green) %>"
    rescue => error
      fail( "Failed to configure the puppetserver, with error #{error.message}" )
    end

    # Firstrun is tagged and run against the bootstrap puppetserver port, 8150.
    # This run will configure puppetserver and puppetdb; all subsequent runs
    # will run against the conifgured masterport.
    say "> <%= color('Running puppet agent, with --tags pupmod,simp', :cyan) %>"
    pupcmd = 'puppet agent --onetime --no-daemonize --no-show_diff --verbose --no-splay --masterport=8150 --ca_port=8150'
    # Firstrun is tagged and run against the bootstrap puppetserver port, 8150.
    linecounts << track_output("#{pupcmd} --tags pupmod,simp 2> /dev/null", '8150')

    # If selinux is enabled, relabel the filesystem.
    FileUtils.touch('/.autorelabel')
    if Facter.value(:selinux) && !Facter.value(:selinux_current_mode).nil? && (Facter.value(:selinux_current_mode) != "disabled")
      say "> <%= color('Relabeling filesystem for selinux.', :cyan) %>"
      @logfile.puts("Relabeling filesystem for selinux.\n")
      system("fixfiles -f relabel 2>&1 | tee -a #{@logfile.path}")
    end

    # SIMP is not single-run idempotent.  Until it is, run puppet twice.
    say "> <%= color('Running puppet without tags', :cyan) %>"
    pupcmd = "puppet agent --onetime --no-daemonize --no-show_diff --verbose --no-splay"
    # This is fugly, but until we devise an intelligent way to determine when your system
    # is 'bootstrapped', we're going to run puppet in a loop.
    (0..1).each do
      track_output("#{pupcmd}")
    end

    # Clean up the leftover puppetserver process (if any)
    begin
      pserver_proc = %x{netstat -tlpn}.split("\n").select{|x| x =~ /\d:8150/}
      unless pserver_proc.empty?
        pserver_pid = pserver_proc.first.split.last.split('/').first.to_i
        Process.kill('KILL',pserver_pid)
      end
    rescue Exception => e
      say e
      say "> <%= color('The Puppet Server process running on port 8150 could not be killed. Please check your configuration!', :magenta) %>"
    end

    # Print closing banner
    say "> <%= color('SIMP Bootstrap Complete!', :yellow) %>"
    say "> Duration of complete bootstrap: #{Time.now - bootstrap_start_time} seconds"
    if !system('ps -C httpd > /dev/null 2>&1') && (linecounts.include?(-1) || (linecounts.uniq.length < linecounts.length))
      say "> <%= color('Warning: Primitive checks indicate there may have been issues.', :magenta) %>"
    end
    say "> <%= color('Check #{@logfile.path} for details', :yellow) %>"
    say "> <%= color('Please run `puppet agent -t` by hand to test your configuration.', :yellow) %>"
    say "> <%= color('You should reboot your system to ensure consistency', :magenta) %>"
  end
end
