module Simp::Cli::Commands; end

require 'simp/cli/config/items/action/set_production_to_simp_action'
require 'highline/import'
require 'highline'

class Simp::Cli::Commands::Bootstrap < Simp::Cli
  require 'pty'
  require 'timeout'
  require 'facter'
  require File.expand_path( '../defaults', File.dirname(__FILE__) )
  HighLine.colorize_strings

  @start_time = Time.now
  @start_time_formatted = @start_time.strftime('%Y%m%dT%H%M%S')
  @bootstrap_log = File.join(SIMP_CLI_HOME, "simp_bootstrap.log.#{@start_time_formatted}")
  @bootstrap_backup = "#{SIMP_CLI_HOME}/simp_bootstrap.backup.#{@start_time_formatted}"

  @verbose = false
  @track = true
  @unsafe = false
  @opt_parser = OptionParser.new do |opts|
    opts.banner = "\n=== The SIMP Bootstrap Tool ==="
    opts.separator "\nThe SIMP Bootstrap Tool aids initial configuration of the system by"
    opts.separator "bootstrapping it. This should be run after 'simp config' has applied a new"
    opts.separator "system configuration.\n\n"
    opts.separator "Prior to configuration, any running puppet agents are allowed to complete"
    opts.separator "their runs. If you wish to forcibly kill a running agent, pass --kill_agent\n\n"
    opts.separator "The tool configures and starts a puppetserver with minimal memory, on"
    opts.separator "port 8150.  It applies the simp and pupmod modules to the system which"
    opts.separator "will configure the puppetserver and puppetdb services according to the system"
    opts.separator "configuration (values set in simp config).  Two tagless puppet runs follow,"
    opts.separator "to apply all other core modules.\n\n"
    opts.separator "By default, this tool will prompt to keep or remove existing puppetserver"
    opts.separator "certificates. To skip the prompt, see --[no]-remove_ssldir.\n\n"
    opts.separator "This utility can be run more than once, but is it not recommended."
    opts.separator "Note what options are available before re-running.\n\n"
    opts.separator "Logging information about the run is written to #{SIMP_CLI_HOME}/simp_bootstrap.log.*"
    opts.separator "Prior to modification, config files are backed up to #{SIMP_CLI_HOME}/simp_bootstrap.backup.*\n\n"
    opts.separator "OPTIONS:\n"

    opts.on("-v", "--[no-]verbose", "Enables/disables verbose mode. Prints out verbose information.") do |v|
      @verbose = v
    end

    opts.on("-k", "--kill_agent",  "Ignore the status of agent_catalog_run_lockfile, and",
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
                              "and ignored, which may result in a corrupt system. Useful for",
                              "debugging. Default is SAFE.") do |u|
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

    # Set us up to use the SIMP environment, if this has not already been done.
    # (1) Be careful to preserve the existing primary, 'production' environment,
    #     if one exists.
    # (2) Create links to production in both the primary and secondary environment
    #     paths.
    environment_path = ::Utils.puppet_info[:simp_environment_path]
    fail("Could not find the simp environment path at #{environment_path}") unless File.directory?(environment_path)

    item = Simp::Cli::Config::Item::SetProductionToSimpAction.new
    item.start_time = @start_time
    item.apply
    fail ("Could not set 'simp' to production environment") unless item.applied_status == :succeeded

    linecounts = Array.new

    # Open log file, and create storage for backups.
    logfilepath = File.dirname(File.expand_path(@bootstrap_log))
    unless File.exists?(logfilepath)
      FileUtils.mkpath(logfilepath)
    end
    @logfile = File.open(@bootstrap_log, 'w')
    FileUtils.mkdir(@bootstrap_backup)

    # Print intro
    system('clear')
    say "=== Starting SIMP Bootstrap ===".yellow.bold

    # Set an interrupt trap if safe mode is enabled
    say "> The log can be found at '#{@logfile.path}'\n"

    # Determine if a puppet agent is running, and what to do with it.
    agent_run_lockfile = ::Utils.puppet_info[:config]['agent_catalog_run_lockfile']
    if @kill_agent
      say "> Killing puppet agents".cyan
      system("pkill -9 -f 'puppet agent' >& /dev/null")
      system("puppet resource service puppet ensure=stopped >& /dev/null")
      system("rm -f #{agent_run_lockfile}")
      say "> Successfully removed agent lock file #{agent_run_lockfile}".green
    else
      run_locked = File.exists?(agent_run_lockfile)
      # TODO: make the following spinner a function; it's used in ensure_running as well.
      if run_locked
        say "> Detected puppet agent run lockfile #{agent_run_lockfile}".magenta
        say "> Waiting for agent run to complete".cyan
        say ">  If you wish to forcibly kill a running agent during bootstrap, re-run with --kill_agent"
        say ">  Otherwise, you can wait for the lock to release or manually stop the running agent"
        stages = ["\\",'|','/','-']
        rest = 0.1
        timeout = 5
        Timeout::timeout(timeout*60) {
          while run_locked do
            run_locked = File.exists?(agent_run_lockfile)
            stages.each{ |x|
              $stdout.flush
              print "> #{x}\r"
              sleep(rest)
            }
          end
        }
        $stdout.flush
      else
        say "> DEBUG: Did not detect a running puppet agent" if @verbose
      end
    end

    # Now, disable non-bootstrap agent runs
    # Don't need to re-enable agents, puppetagent_cron will do that
    system("puppet agent --disable Bootstrap")
    say "> Successfully disabled non-bootstrap puppet agent".green

    # From this point on, capture interrupts
    if not @unsafe
      signals = ["INT","HUP","USR1","USR2"]
      signals.each do |sig|
        Signal.trap(sig) { say "\nSafe mode enabled, ignoring interrupt".magenta }
      end
      say "> Interrupts will be captured and ignored to ensure bootstrap integrity.".magenta.bold
    else
      say "> WARNING: Any interrupts may cause system instability.".red.bold
    end

    # Kill the connection with puppetdb before killing the puppetserver
    say "> Killing connection to puppetdb".cyan
    system("puppet resource service puppetdb ensure=stopped >& /dev/null")
    system("pkill -9 -f puppetdb")
    confdir = ::Utils.puppet_info[:config]['confdir']
    if File.exists?("#{confdir}/routes.yaml")
      FileUtils.mkdir_p("#{@bootstrap_backup}/#{confdir}")
      FileUtils.cp("#{confdir}/routes.yaml","#{@bootstrap_backup}/#{confdir}")
      say "> Successfully backed up #{confdir}/routes.yaml to #{@bootstrap_backup}#{confdir}".green
      system("rm -f #{confdir}/routes.yaml")
      say "> Successfully removed #{confdir}/routes.yaml".green
    else
      say "> DEBUG: Did not find #{confdir}/routes.yaml, not removing" if @verbose
    end
    system('puppet config set --section master storeconfigs false')
    system('puppet config set --section main storeconfigs false')
    say "> DEBUG: Successfully set storeconfigs=false in #{confdir}/puppet.conf".green if @verbose

    # Kill all puppet processes and stop specific services
    say "> Killing all remaining puppet processes".cyan
    system("puppet resource service puppetserver ensure=stopped >& /dev/null")
    system("pkill -9 -f puppet >& /dev/null")
    system('pkill -f pserver_tmp')

    rm_ssldir = @remove_ssldir
    # If no flag was passed, it's nil and we should prompt
    if @remove_ssldir.nil?
      say "> Removing the contents of the puppet ssldir will ensure consistency, but"
      say ">   may not be desireable.  If removed, puppetserver certificates will be"
      say ">   removed and re-generated."
      rm_ask = ask("> Do you wish to remove the existing ssldir? (yes|no) ".yellow) { |q| q.validate = /(yes)|(no)/i }
      if rm_ask.downcase == 'yes'
        rm_ssldir = true
      else
        rm_ssldir = false
      end
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

    # Get a puppetserver service running and listening on 8150.
    # - Many of our modules depend on server_facts, which require a running puppetserver.
    #   Otherwise, puppet applys would suffice.
    # - The port against which we do firstrun, 8150, is arbitrary. The first run is a
    #   tagged run with pupmod and simp, which will take the data from simp config and
    #   re-configure puppetserver/puppetdb with it.
    say "> Configuring the puppetserver to listen on port 8150".cyan
    begin
      # Back everything up!
      puppetserver_dir = '/etc/puppetlabs/puppetserver/conf.d'
      if File.directory?(puppetserver_dir)
        conf_files = ["#{puppetserver_dir}/webserver.conf",
                      "#{puppetserver_dir}/web-routes.conf",
                      '/etc/sysconfig/puppetserver']
        conf_files.each do |f|
          if File.exists?(f)
            FileUtils.mkdir_p("#{@bootstrap_backup}/#{File.dirname(f)}")
            FileUtils.cp(f,"#{@bootstrap_backup}/#{File.dirname(f)}")
            say "> Successfully backed up #{f} to #{@bootstrap_backup}#{f}".green
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
      say "> Successfully wrote java tmpdir to /etc/sysconfig/puppetserver".green

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
      say "> Successfully wrote webserver.conf to #{puppetserver_dir}/webserver.conf".green
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
      say "> Successfully wrote web-routes.conf to #{puppetserver_dir}/web-routes.conf".green
    rescue => error
      fail( "Failed to configure the puppetserver, with error #{error.message}" )
    end

    # - Firstrun is tagged and run against the bootstrap puppetserver port, 8150.
    #   This run will configure puppetserver and puppetdb; all subsequent runs
    #   will run against the configured masterport.
    # - Create a unique lockfile, we want to preserve the lock on cron and manual
    #   puppet runs during bootstrap.
    agent_lockfile = "#{File.dirname(::Utils.puppet_info[:config]['agent_disabled_lockfile'])}/bootstrap.lock"
    pupcmd = "puppet agent --onetime --no-daemonize --no-show_diff --verbose --no-splay --agent_disabled_lockfile=#{agent_lockfile} --masterport=8150 --ca_port=8150"

    say "> Running puppet agent, with --tags pupmod,simp".cyan

    # Firstrun is tagged and run against the bootstrap puppetserver port, 8150.
    linecounts << track_output("#{pupcmd} --tags pupmod,simp 2> /dev/null", '8150')

    # If selinux is enabled, relabel the filesystem.
    # TODO: grab the simp config spinner and run fixfiles in it.
    FileUtils.touch('/.autorelabel')
    if Facter.value(:selinux) && !Facter.value(:selinux_current_mode).nil? && (Facter.value(:selinux_current_mode) != "disabled")
      say "> Relabeling filesystem for selinux (this may take a while...)".cyan
      @logfile.puts("Relabeling filesystem for selinux.\n")
      # This is silly, but there does not seem to be a way to get fixfiles
      # to shut up without specifying a logfile.  Stdout/err still make it to
      # the our logfile.
      system("fixfiles -l /dev/null -f relabel 2>&1 >> #{@logfile.path}")
    end

    # SIMP is not single-run idempotent.  Until it is, run puppet twice.
    say "> Running puppet without tags".cyan
    pupcmd = "puppet agent --onetime --no-daemonize --no-show_diff --verbose --no-splay --agent_disabled_lockfile=#{agent_lockfile}"
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
    say "> Duration of complete bootstrap: #{Time.now - @start_time} seconds"
    if !system('ps -C httpd > /dev/null 2>&1') && (linecounts.include?(-1) || (linecounts.uniq.length < linecounts.length))
      say "> Warning: Primitive checks indicate there may have been issues".magenta
    end
    say "> Check #{@logfile.path} for details".yellow
    say "> Please run `puppet agent -t` by hand to test your configuration".yellow
    say "> You should reboot your system to ensure consistency".magenta

    # Re-enable the non-bootstrap puppet agent
    system("puppet agent --enable")
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
