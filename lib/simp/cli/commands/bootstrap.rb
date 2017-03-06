module Simp::Cli::Commands; end

require 'simp/cli/config/items/action/set_production_to_simp_action'
require 'highline/import'
require 'highline'

class Simp::Cli::Commands::Bootstrap < Simp::Cli
  require 'pty'
  require 'timeout'
  require 'facter'
  require File.expand_path( '../defaults', File.dirname(__FILE__) )
  BOOTSTRAP_LOG = File.join(SIMP_CLI_HOME, "simp_bootstrap.log.#{Time.now.strftime('%Y%m%dT%H%M%S')}")
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

    opts.on("-k", "--[no-]kill_agent", "Ignore the status of agent_catalog_run_lockfile, and",
                                             "force kill active puppet agents at the beginning of",
                                             "bootstrap") do |k|
      @kill_agent = k
    end

    opts.on("-r", "--[no-]remove_ssldir", "Remove the existing puppet ssldir. Default is KEEP.") do |r|
      @remove_ssldir = r
    end

    opts.on("-t", "--[no-]track", "Enables/disables the tracker. Default is enabled.") do |t|
      @track = t
    end

    opts.on("-u", "--unsafe", "Run bootstrap in 'unsafe' mode.  Interrupts are NOT captured",
                              "and ignored. Useful for debugging. Default is SAFE.") do |u|
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
    say "=== Starting SIMP Bootstrap ===".yellow.bold

    # Set an interrupt trap if safe mode is enabled
    say "> The log can be found at '#{@logfile.path}'\n"
    if not @unsafe
      signals = ["INT","HUP","USR1","USR2"]
      signals.each do |sig|
        Signal.trap(sig) { say "\nSafe mode enabled, ignoring interrupt".magenta }
      end
      say "> Interrupts will be captured and ignored to ensure bootstrap integrity.".magenta.bold
    else
      say "> WARNING: Any interrupts may cause system instability.".red.bold
    end

    # Check if a puppet agent is currently running
    # Note: Killing a puppet agent (that started via cron) will release the lock it has on
    # /var/puppetagent_cron.lock
    if not @kill_agent then
      if File.exists?(::Utils.puppet_info[:config]['agent_catalog_run_lockfile'])
        say "> Detected running puppet agent process".magenta
        if not @kill_agent == false
          pkill_ask = ask ("> Do you wish to kill it? (yes|no) ".yellow) { |q| q.validate = /(yes)|(no)/i}
          pkill_ask = false if pkill_ask.downcase == 'no'
        end
        if pkill_ask == false or @kill_agent == false
          say "> Not killing active puppet agent process(es)".magenta
          say "> You will need to resolve all running agent processes before continuing".magenta
          exit 1
        end
      else
        say "> Did not detect any active puppet agents"
      end
    end

    # Grab a lock on puppetagent cron so it does not esplode bootstrap.
    File.open("/var/puppetagent_cron.lock", File::RDWR|File::CREAT, 0644) {|f|
      f.flock(File::LOCK_EX)

      # Kill all puppet processes and stop specific services
      say "> Killing all Puppet processes".cyan
      system("pkill -9 -f puppet >& /dev/null")
      system('pkill -f pserver_tmp')
      system("puppet resource service puppetserver ensure=stopped >& /dev/null")

      # Kill the connection with puppetdb
      say "> Killing connection to PuppetDB".cyan
      system("puppet resource service puppetdb ensure=stopped >& /dev/null")
      confdir = ::Utils.puppet_info[:config]['confdir']
      if File.exists?("#{confdir}/routes.yaml")
        system("rm -f #{confdir}/routes.yaml")
        say "> DEBUG: Successfully removed #{confdir}/routes.yaml".green if @verbose
      else
        say "> DEBUG: Did not find #{confdir}/routes.yaml, not removing" if @verbose
      end
      system('puppet config set --section master storeconfigs false')
      system('puppet config set --section main storeconfigs false')
      say "> DEBUG: Successfully set storeconfigs=false in #{confdir}/puppet.conf".green if @verbose

      # Figure out what to do with the puppet ssldir
      rm_ssldir = false
      if @remove_ssldir then
        rm_ssldir = true
      # If remove_ssldir is not true OR false, it is nil and should be prompted for.
      elsif not @remove_ssldir == false
        say "> Removing the contents of the puppet ssldir will ensure consistency, but"
        say ">   may not be desireable.  If removed, puppetserver certificates will be"
        say ">   removed and re-generated."
        rm_ask = ask("> Do you wish to remove the existing ssldir? (yes|no) ".yellow) { |q| q.validate = /(yes)|(no)/i }
        rm_ssldir = true if rm_ask.downcase == 'yes'
      end
      ssldir = ::Utils.puppet_info[:config]['ssldir']
      if rm_ssldir
        FileUtils.rm_rf(Dir.glob(File.join(ssldir,'*')))
        say "> Successfully removed #{ssldir}/*".green
      else
        say "> Keeping current puppetserver certificates, in #{ssldir}".green
      end

      # Remove the run directory
      rundir = ::Utils.puppet_info[:config]['rundir']
      FileUtils.rm_f(Dir.glob(File.join(rundir,'*')))
      say "> Successfully removed #{rundir}/*".green

      # Get the puppetserver configured to listen on port 8150.
      say "> Configuring puppetserver to listen on port 8150".cyan
      begin

        # Back everything up.
        puppetserver_dir = '/etc/puppetlabs/puppetserver/conf.d'
        if File.directory?(puppetserver_dir)
          conf_files = ["#{puppetserver_dir}/webserver.conf", "#{puppetserver_dir}/web-routes.conf", '/etc/sysconfig/puppetserver']
          conf_files.each do |f|
            if File.exists?(f)
              system(%{cp #{f} #{f}.BAK})
              say "> Sucessfully backed up #{f} to #{f}.BAK".green
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
        say "> Sucessfully wrote java tmpdir to /etc/sysconfig/puppetserver".green

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
        say "> Sucessfully wrote webserver.conf to #{puppetserver_dir}/webserver.conf".green
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
        say "> Sucessfully wrote web-routes.conf to #{puppetserver_dir}/web-routes.conf".green
      rescue => error
        fail( "Failed to configure the puppetserver, with error #{error.message}" )
      end

      # Firstrun is tagged and run against the bootstrap puppetserver port, 8150.
      # This run will configure puppetserver and puppetdb; all subsequent runs
      # will run against the conifgured masterport.
      say "> Running puppet agent, with --tags pupmod,simp".cyan
      pupcmd = 'puppet agent --onetime --no-daemonize --no-show_diff --verbose --no-splay --masterport=8150 --ca_port=8150'
      # Firstrun is tagged and run against the bootstrap puppetserver port, 8150.
      linecounts << track_output("#{pupcmd} --tags pupmod,simp 2> /dev/null", '8150')

      # If selinux is enabled, relabel the filesystem.
      FileUtils.touch('/.autorelabel')
      if Facter.value(:selinux) && !Facter.value(:selinux_current_mode).nil? && (Facter.value(:selinux_current_mode) != "disabled")
        say "> Relabeling filesystem for selinux".cyan
        @logfile.puts("Relabeling filesystem for selinux.\n")
        system("fixfiles -f relabel 2>&1 | tee -a #{@logfile.path}")
      end

      # SIMP is not single-run idempotent.  Until it is, run puppet twice.
      say "> Running puppet without tags".cyan
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
          pserver_port = %x{puppet config print masterport}
          # By this point, bootstrap has applied config settings to puppetserver.
          # Don't kill puppetserver if it's configured it to listen on 8150.
          unless (pserver_port == '8150')
            pserver_pid = pserver_proc.first.split.last.split('/').first.to_i
            Process.kill('KILL',pserver_pid)
          end
        end
      rescue Exception => e
        say e
        say "> The bootstrap puppetserver process running on port 8150 could not be killed. Please check your configuration!".magenta
      end

      # Print closing banner
      say "> SIMP Bootstrap Complete!".yellow
      say "> Duration of complete bootstrap: #{Time.now - bootstrap_start_time} seconds"
      if !system('ps -C httpd > /dev/null 2>&1') && (linecounts.include?(-1) || (linecounts.uniq.length < linecounts.length))
        say "> Warning: Primitive checks indicate there may have been issues".magenta
      end
      say "> Check #{@logfile.path} for details".yellow
      say "> Please run `puppet agent -t` by hand to test your configuration".yellow
      say "> You should reboot your system to ensure consistency".magenta

      # Un-lock the puppetagent cron
      f.flock(File::LOCK_UN)
    }
  end

  # Ensure the puppetserver is running ca on the specified port.
  # Used ensure the puppetserver service is running.
  def self.ensure_running(port = nil)
    port ||= `puppet config print masterport`.chomp

    begin
      say "> Waiting for puppetserver to accept connections on port #{port}".cyan
      curl_cmd = "curl -sS --cert #{::Utils.puppet_info[:config]['certdir']}/`hostname`.pem --key #{::Utils.puppet_info[:config]['ssldir']}/private_keys/`hostname`.pem -k -H \"Accept: s\" https://localhost:#{port}/production/certificate_revocation_list/ca"
      say "> DEBUG: #{curl_cmd}" if @verbose
      running = (%x{#{curl_cmd} 2>&1} =~ /CRL/)
      unless running
        system('puppet resource service puppetserver ensure="running" enable=true > /dev/null 2>&1 &')
        stages = ["\\",'|','/','-']
        rest = 0.1
        timeout = 5
        Timeout::timeout(timeout*60) {
          while not running do
            running = (%x{#{curl_cmd} 2>&1} =~ /CRL/)
            stages.each{ |x|
              $stdout.flush
              print "> #{x}\r"
              sleep(rest)
            }
          end
        }
        $stdout.flush
      end
    rescue Timeout::Error
      fail("The Puppet Server did not start within #{timeout} minutes. Please start puppetserver by hand and inspect any issues.")
    end
  end

  # Track a running process by following its STDOUT output
  # Prints a '#' for each line of output
  # returns -1 if error occured, otherwise the line count if PTY.spawn succeeded
  def self.track_output(command, port = nil)
    say "> DEBUG: #{command}" if @verbose
    ensure_running(port)
    successful = true

    @logfile.print '#' * 80
    @logfile.puts("\nStarting #{command}\n")

    start_time = Time.now
    linecount = 0
    col = ['green','red','yellow','blue','magenta','cyan']

    if @track
      say "> Track => ".cyan
      begin
        ::PTY.spawn("#{command}") do |read, write, pid|
          begin
            read.each do |line|
              print ("#".send(col.first))
              col.rotate!
              @logfile.puts(line)
              linecount += 1
            end
          rescue Errno::EIO
          end
        end
      rescue PTY::ChildExited => e
        print '!!!'
        @logfile.puts("Child exited unexpectedly:\n\t#{e.message}")
        successful = false
      rescue
        # If we don't have a PTY, just run the command.
        @logfile.puts "Running without a PTY!"
        output = %x{#{command}}
        @logfile.puts output
        linecount = output.split("\n").length
        successful = false if $? != 0
      end
    else # don't track
      say "> Running, please wait ... "
      $stdout.flush
      output = %x{#{command}}
      @logfile.puts output
      linecount = output.split("\n").length
      successful = false if $? != 0
    end
    puts
    @logfile.puts("\n#{command} - Done!")
    end_time = Time.now
    say "> DEBUG: Duration of Puppet run: #{end_time - start_time} seconds" if @verbose
    @logfile.puts("Duration of Puppet run: #{end_time - start_time} seconds")

    return successful ? linecount : -1
  end

end
