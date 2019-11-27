require 'simp/cli/commands/command'
require 'simp/cli/config/simp_puppet_env_helper'
require 'highline/import'

class Simp::Cli::Commands::Bootstrap < Simp::Cli::Commands::Command
  require 'pty'
  require 'timeout'

  DEFAULT_PUPPETSERVER_WAIT_MINUTES = 5

  def initialize
    @puppetserver_wait_minutes = DEFAULT_PUPPETSERVER_WAIT_MINUTES

    @start_time = Time.now
    @start_time_formatted = @start_time.strftime('%Y%m%dT%H%M%S')
    @bootstrap_log = File.join(Simp::Cli::SIMP_CLI_HOME, "simp_bootstrap.log.#{@start_time_formatted}")
    @bootstrap_backup = "#{Simp::Cli::SIMP_CLI_HOME}/simp_bootstrap.backup.#{@start_time_formatted}"

    @kill_agent = false
    @remove_ssldir = nil
    @track = true
    @unsafe = false
    @verbose = false

    @is_pe = Simp::Cli::Utils::puppet_info[:is_pe]
  end

  #####################################################
  # Simp::Cli::Commands::Command API methods
  #####################################################
  #
  def description
    'Bootstrap initial SIMP server'
  end

  def help
    parse_command_line( [ '--help' ] )
  end

  def run(args)
    parse_command_line(args)
    return if @help_requested

    set_up_logger
    print_intro
    verify_setup

    prep_for_first_puppet_run

    # - First set of runs are tagged and run against the bootstrap puppetserver
    #   port.  These initial runs will configure puppetserver and puppetdb; all
    #   subsequent runs will run against the configured masterport.
    # - Create a unique lockfile, we want to preserve the lock on cron and manual
    #   puppet runs during bootstrap.
    agent_lockfile = "#{File.dirname(Simp::Cli::Utils.puppet_info[:config]['agent_disabled_lockfile'])}/bootstrap.lock"

    pupcmd = "puppet agent --onetime --no-daemonize --no-show_diff --verbose" +
      " --no-splay --agent_disabled_lockfile=#{agent_lockfile}" +
      " --masterport=#{@initial_puppetserver_port} --ca_port=#{@initial_puppetserver_port}"

    num_tagged_runs = 3
    info("Running puppet agent with --tags pupmod,simp up to #{num_tagged_runs} times...", 'cyan')
    pupcmd = "#{pupcmd} --tags pupmod,simp 2> /dev/null"
    linecounts = Array.new
    (1..num_tagged_runs).each do |run_num|
      info("Tagged agent run #{run_num}:", 'cyan')
      # Tagged runs are against the bootstrap puppetserver port
      linecounts << track_output(pupcmd, @initial_puppetserver_port)

      # As soon as we have configured the puppetserver beyond the initial port
      # and restarted the service (all done via puppet), it won't be running on
      # the initial port and we are done with tagged runs.
      break unless puppetserver_running?(@initial_puppetserver_port, true)
    end

    fix_file_contexts

    # After the first set of tagged runs the puppetserver will normally come up
    # on a different port, reloading puppetserver to apply this change
    #
    # TODO: Validate that the pupmod-simp-pupmod tests are properly checking
    # for the server restart with a port switch. This has not traditionally
    # been a problem and having this statement does no harm but it should not
    # be required.
    info('Reloading puppetserver', 'cyan')
    execute('puppetserver reload')

    # SIMP is not single-run idempotent.  Until it is, run puppet multiple times.
    num_runs = 4
    info("Running puppet agent without tags #{num_runs} times...", 'cyan')
    pupcmd = 'puppet agent --onetime --no-daemonize --no-show_diff --verbose --no-splay' +
      " --agent_disabled_lockfile=#{agent_lockfile}"
    # This is ugly, but until we devise an intelligent way to determine when your system
    # is 'bootstrapped', we're going to run puppet in a loop.
    (1..num_runs).each do |run_num|
      info("Standard agent run #{run_num}:", 'cyan')
      track_output(pupcmd)
    end

    unless @is_pe
      ensure_bootstrap_puppetserver_process_stopped
    end

    print_closing_banner(linecounts)

    info('Re-enabling the non-bootstrap puppet agent', 'cyan')
    execute('puppet agent --enable')
  end

  #####################################################
  # Custom methods
  #####################################################

  private

  # Verifies SIMP environment exists and is valid
  def check_for_simp_environment
    info("Checking for the SIMP omni-environment '#{Simp::Cli::BOOTSTRAP_PUPPET_ENV}'", 'cyan')

    # FIXME  This is an interim way to affect the validation.  Will use
    #   Simp::Cli::Environment::OmniEnvController once logic is available.
    status_code, status_details = Simp::Cli::Config::SimpPuppetEnvHelper.new(Simp::Cli::BOOTSTRAP_PUPPET_ENV).env_status

    unless status_code == :exists
      details_msg = status_details.split("\n").map { |line| '  >>' + line }.join("\n")
      msg = "A valid SIMP omni-environment for '#{Simp::Cli::BOOTSTRAP_PUPPET_ENV}' does not exist:\n"
      msg += details_msg
      fail(msg)
    end
  end

  # Check for bootstrap start lock
  def check_for_start_lock
    # During simp config, critical failed items are logged in a lock file. If the file
    # exists, don't bootstrap.
    info('Checking for a bootstrap start lock', 'cyan')
    if File.exist?(Simp::Cli::BOOTSTRAP_START_LOCK_FILE)
      fail("Bootstrap cannot proceed until problem identified in\n" +
           "#{Simp::Cli::BOOTSTRAP_START_LOCK_FILE} is solved and that file is removed.")
    end
  end

  # Configure an initial, bootstrap puppetserver service listening on 8150
  # - Many of our modules depend on server_facts, which require a running puppetserver.
  #   Otherwise, puppet applys would suffice.
  # - The port against which we do firstrun, 8150, is arbitrary. The first puppet run
  #   is a tagged run with pupmod and simp, which will re-configure puppetserver/puppetdb
  #   with the operational configuration parameters generated by simp config.
  # - Only executed for FOSS puppet
  def configure_bootstrap_puppetserver
    info('Configuring the puppetserver to listen on port 8150 for first puppet agent run', 'cyan')
    begin
      # Back everything up!
      # TODO Execute all back up of puppet-related config in one place?  Some
      # backup is done in ensure_puppet_processes_stopped()...Leads to odd set
      # of log messages for user.
      puppetserver_conf_dir = '/etc/puppetlabs/puppetserver/conf.d'
      unless File.directory?(puppetserver_conf_dir)
        fail( "Could not find directory #{puppetserver_conf_dir}" )
      end

      conf_files = [
        "#{puppetserver_conf_dir}/webserver.conf",
        "#{puppetserver_conf_dir}/web-routes.conf",
        '/etc/sysconfig/puppetserver',
        '/etc/puppetlabs/puppet/auth.conf'
      ]

      conf_files.each do |file|
        if File.exists?(file)
          backup_dir = File.join(@bootstrap_backup, File.dirname(file))
          FileUtils.mkdir_p(backup_dir)
          FileUtils.cp(file, backup_dir)
          info("Successfully backed up #{file} to #{backup_dir}", 'green')
        end
      end

      # /etc/puppetlabs/puppet/auth.conf is installed by some versions of puppet-agent.
      # SIMP manages auth.conf in /etc/puppetlabs/puppetserver/conf.d.  Back up and
      # remove existing /etc/puppetlabs/puppet/auth.conf file.
      if File.exists?('/etc/puppetlabs/puppet/auth.conf')
        FileUtils.rm('/etc/puppetlabs/puppet/auth.conf')
        info("Removed /etc/puppetlabs/puppet/auth.conf", 'green')
      end

      # Run in a temporary cache space.
      vardir_stat = File.stat(Simp::Cli::Utils.puppet_info[:config]['vardir'])

      # Ensure that the ownership is correct
      server_conf_tmp = "#{Simp::Cli::Utils.puppet_info[:config]['vardir']}/pserver_tmp"
      FileUtils.mkdir_p(server_conf_tmp)
      FileUtils.chown(vardir_stat.uid, vardir_stat.gid, server_conf_tmp)
      FileUtils.chmod(vardir_stat.mode & 0777, server_conf_tmp)

      java_args = [
        '-Xms2g',
        '-Xmx2g',
        # Java 8 dropped -XX:MaxPermSize
        %{-Djava.io.tmpdir=#{server_conf_tmp}}
      ]

      if (java_major_version && (java_major_version < 8))
        java_args << '-XX:MaxPermSize=256m'
      end

      java_args = java_args.join(' ')

      %x{grep -q '^JAVA_ARGS' /etc/sysconfig/puppetserver}

      if $?.success?
        command = %{sed -i 's|^JAVA_ARGS.*|JAVA_ARGS="#{java_args}"|' /etc/sysconfig/puppetserver}
      else
        command = %{echo 'JAVA_ARGS="#{java_args}"' >> /etc/sysconfig/puppetserver}
      end

      execute(command)
      info('Successfully configured /etc/sysconfig/puppetserver to use a temporary cache', 'green')

      # Slap minimalistic conf files in place to get puppetserver off of the ground.
      webserver_conf = "#{puppetserver_conf_dir}/webserver.conf"
      File.open(webserver_conf, 'w') do |file|
        file.puts <<-EOM
webserver: {
    access-log-config: /etc/puppetlabs/puppetserver/request-logging.xml
    client-auth: want
    ssl-host: 0.0.0.0
    ssl-port: 8150
}
EOM
      end
      File.chmod(0644, webserver_conf)
      info("Successfully configured #{webserver_conf} with bootstrap settings", 'green')


      # Reset the web-routes.conf file since the CA service is now gone
      web_routes_conf = "#{puppetserver_conf_dir}/web-routes.conf"
      File.open(web_routes_conf, 'w') do |file|
        file.puts <<-EOM
web-router-service: {
  "puppetlabs.services.ca.certificate-authority-service/certificate-authority-service": "/puppet-ca"
  "puppetlabs.services.legacy-routes.legacy-routes-service/legacy-routes-service": ""
  "puppetlabs.services.master.master-service/master-service": "/puppet"
  "puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service": "/puppet-admin-api"
  "puppetlabs.trapperkeeper.services.metrics.metrics-service/metrics-webservice": "/metrics"
  "puppetlabs.trapperkeeper.services.status.status-service/status-service": "/status"
}
EOM
      end

      File.chmod(0644, web_routes_conf)
      info("Successfully configured #{web_routes_conf} with bootstrap settings", 'green')

    rescue => error
      fail( "Failed to configure the puppetserver with bootstrap settings: #{error.message}" )
    end
  end

  # Clean up the leftover, bootstrap puppetserver process (if any)
  def ensure_bootstrap_puppetserver_process_stopped
    begin
      pserver_proc = %x{netstat -tlpn}.split("\n").select{|x| x =~ /\d:8150/}
      unless pserver_proc.empty?
        pserver_port = %x{puppet config print --section=master masterport}.strip
        # By this point, bootstrap has applied config settings to puppetserver.
        # Don't kill puppetserver if it's configured it to listen on 8150.
        unless (pserver_port == '8150')
          info('Ensuring bootstrap puppetserver process is stopped', 'cyan')
          pserver_pid = pserver_proc.first.split.last.split('/').first.to_i
          Process.kill('KILL',pserver_pid)
        end
      end
#TODO need to separately rescue exception raised by Process.kill for process
#that no longer exists, as that is clearly no longer a problem
    rescue Exception => e
      warn(e.message)
      warn("The bootstrap puppetserver process running on port 8150 could not be killed." +
        "\n Please check your configuration!", 'magenta')
    end
  end

  # Ensure puppet agent is stopped and disabled
  def ensure_puppet_agent_stopped
    info('Ensuring puppet agent is stopped and disabled', 'cyan')
    agent_run_lockfile = Simp::Cli::Utils.puppet_info[:config]['agent_catalog_run_lockfile']
    if @kill_agent
      info('Killing puppet agents', 'cyan')
      execute("pkill -9 -f 'puppet agent' >& /dev/null")
      execute('puppet resource service puppet ensure=stopped >& /dev/null')
      FileUtils.rm_f(agent_run_lockfile)
      info("Successfully removed agent lock file #{agent_run_lockfile}", 'green')
    else
      run_locked = File.exists?(agent_run_lockfile)
      # TODO: make the following spinner a function; it's used in ensure_puppetserver_running as well.
      if run_locked
        info("Detected puppet agent run lockfile #{agent_run_lockfile}", 'magenta')
        info('Waiting for agent run to complete', 'cyan')
        info('  If you wish to forcibly kill a running agent during bootstrap, re-run with --kill_agent')
        info('  Otherwise, you can wait for the lock to release or manually stop the running agent')
        stages = ["\\",'|','/','-']
        rest = 0.1
        while run_locked do
          run_locked = File.exists?(agent_run_lockfile)
          stages.each{ |x|
            $stdout.flush
            print "> #{x}\r"
            sleep(rest)
          }
        end
        $stdout.flush
      else
        debug('Did not detect a running puppet agent')
      end
    end

    # Now, disable non-bootstrap agent runs
    # Don't need to re-enable agents, puppetagent_cron will do that
    execute('puppet agent --disable Bootstrap')
    info('Successfully disabled non-bootstrap puppet agent', 'green')
  end

  # Ensure any remaining puppet processes are stopped
  def ensure_puppet_processes_stopped
    info('Ensuring puppet processes are stopped and puppetserver env is clean', 'cyan')
    # Kill the connection with puppetdb before killing the puppetserver
    info('Killing connection to puppetdb', 'cyan')

    execute("puppet resource service #{@puppetdb_service} ensure=stopped >& /dev/null")
    execute("pkill -9 -f #{@puppetdb_service}")

    confdir = Simp::Cli::Utils.puppet_info[:config]['confdir']
    routes_yaml = File.join(confdir, 'routes.yaml')
    if File.exists?(routes_yaml)
      backup_dir = File.join(@bootstrap_backup, confdir)
      FileUtils.mkdir_p(backup_dir)
      backup_routes_yaml = File.join(backup_dir, 'routes.yaml')
      FileUtils.cp(routes_yaml, backup_routes_yaml)
      info("Successfully backed up #{routes_yaml} to #{backup_routes_yaml}", 'green')
      FileUtils.rm_f(routes_yaml)
      info("Successfully removed #{routes_yaml}", 'green')
    else
      debug("Did not find #{routes_yaml}, not removing")
    end
    execute('puppet config set --section master storeconfigs false')
    execute('puppet config set --section main storeconfigs false')
    debug("Successfully set storeconfigs=false in #{confdir}/puppet.conf", 'green')

    # Kill all puppet processes and stop specific services
    info('Killing all remaining puppet processes', 'cyan')
    execute("puppet resource service #{@puppetserver_service} ensure=stopped >& /dev/null")

    # kill puppet pids *without* killing simp bootstrap
    execute(%q[pids=$(pgrep puppet | egrep -v "$(pgrep -f '\<simp bootstrap' | xargs echo | sed -e 's/ /|/g')") && kill -9 $pids])
    execute('pkill -f pserver_tmp')  # another bootstrap run

    # Remove the run directory
    rundir = Simp::Cli::Utils.puppet_info[:config]['rundir']
    FileUtils.rm_f(Dir.glob(File.join(rundir,'*')))
    info("Successfully removed #{rundir}/*", 'green')
  end

  # Ensure the puppetserver is running ca on the specified port.
  # Used ensure the puppetserver service is running.
  def ensure_puppetserver_running(port = nil)

    # This changes over time so we need to snag it fresh instead of getting it
    # from the originally pulled values.
    port ||= %x{puppet config print --section=master masterport}.strip

    begin
      running = puppetserver_running?(port)
      unless running
        debug('System not running, attempting to restart puppetserver')
        system(%(puppet resource service #{@puppetserver_service} ensure="running" enable=true > /dev/null 2>&1 &))
        stages = ["\\",'|','/','-']
        rest = 0.1
        debug("Waiting up to #{@puppetserver_wait_minutes} minutes for puppetserver to respond")
        Timeout::timeout(@puppetserver_wait_minutes * 60) {
          while not running do
            running = puppetserver_running?(port, true)
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
      fail("The Puppet Server did not start within #{@puppetserver_wait_minutes} minutes. Please start puppetserver by hand and inspect any issues.")
    end
  end

  # If selinux is enabled, relabel the filesystem.
  def fix_file_contexts
    require 'facter'

    FileUtils.touch('/.autorelabel')

    if Facter.value(:selinux) && !Facter.value(:selinux_current_mode).nil? &&
        (Facter.value(:selinux_current_mode) != 'disabled')
      info('Relabeling filesystem for selinux (this may take a while)...', 'cyan')
      # This is silly, but there does not seem to be a way to get fixfiles
      # to shut up without specifying a logfile.  Stdout/err still make it to
      # the our logfile.
      Simp::Cli::Utils::show_wait_spinner {
        execute("fixfiles -l /dev/null -f relabel 2>&1 >> #{@logfile.path}")
      }
    end
  end

  def get_hostname
    %x(hostname -f).strip
  end

  # Remove or retain existing puppet certs per user direction
  def handle_existing_puppet_certs
    info('Checking for existing puppetserver certificates', 'cyan')
    ssldir = Simp::Cli::Utils.puppet_info[:config]['ssldir']
    certs_exist = !Dir.glob(File.join(ssldir, '**', '*.pem')).empty?
    rm_ssldir = @remove_ssldir
    if rm_ssldir.nil?  # not configured
      if certs_exist
        info('Existing puppetserver certificates have been found in')
        info("    #{ssldir}" )
        info('If this server has no registered agents, those certificates can be safely')
        info('removed. Otherwise, although removing them will ensure consistency, manual')
        info('steps may be required to ensure connectivity with existing Puppet clients.')
        info('(See https://docs.puppet.com/puppet/latest/ssl_regenerate_certificates.html)')
        info('Regardless, if removed, new puppetserver certificates will be generated')
        info('automatically.')
        question = "> Do you wish to remove existing puppetserver certificates? (yes|no) "
        rm_ask = ask(question.yellow) { |q| q.validate = /(yes)|(no)/i }
        rm_ssldir = (rm_ask.downcase == 'yes')
      end
    end
    if rm_ssldir
      FileUtils.rm_rf(Dir.glob(File.join(ssldir,'*')))
      info("Successfully removed #{ssldir}/*", 'green')
    else
      info("Keeping current puppetserver certificates, in #{ssldir}", 'green') if certs_exist
    end
  end

  # @return [String] if the Java major version is available
  # @return [nil] if the Java major version is unavailable
  def java_major_version
    return @java_major_version if @java_major_version

    @java_major_version = nil

    java_version = %x{java -version 2>&1}.lines.first

    if $?.success?
      @java_major_version = java_version.strip.split('_')[0].split('.')[1].to_i
    end

    return @java_major_version
  end

  def parse_command_line(args)

    opt_parser = OptionParser.new do |opts|
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
      opts.separator "This utility can be run more than once. Note what options are available"
      opts.separator "before re-running.\n\n"
      opts.separator "Logging information about the run is written to #{Simp::Cli::SIMP_CLI_HOME}/simp_bootstrap.log.*"
      opts.separator "Prior to modification, config files are backed up to #{Simp::Cli::SIMP_CLI_HOME}/simp_bootstrap.backup.*\n\n"
      opts.separator "OPTIONS:\n"

      opts.on('-k', '--kill_agent',
       'Ignore agent_catalog_run_lockfile',
       'status and force kill active puppet',
       'agents at the beginning of bootstrap.'
      ) do |k|
        @kill_agent = true
      end

      opts.on('-r', '--[no-]remove_ssldir',
        'Remove the existing puppet ssldir.',
        'If unspecified, user will be prompted',
        'for action to take.'
      ) do |r|
        @remove_ssldir = r
      end

      opts.on('-t', '--[no-]track',
        'Enables/disables the tracker.',
        'Default is enabled.'
      ) do |t|
        @track = t
      end

      opts.on('-u', '--unsafe',
        "Run bootstrap in 'unsafe' mode.",
        'Interrupts are NOT captured and ignored,',
        'which may result in a corrupt system.',
        'Useful for debugging.',
        'Default is SAFE.'
      ) do |u|
        @unsafe = true
      end

      opts.on('-w', '--puppetserver-wait-minutes MIN', Float,
        'Number of minutes to wait for the',
        'puppetserver to start.',
        "Default is #{DEFAULT_PUPPETSERVER_WAIT_MINUTES} minutes."
      ) do |w|
        @puppetserver_wait_minutes = w
      end

      opts.on('-v', '--[no-]verbose',
        'Enables/disables verbose mode. Prints out',
        'verbose information.'
      ) do |v|
        @verbose = true
      end

      opts.on('-h', '--help', 'Print out this message.') do
        puts opts
        @help_requested = true
      end

    end

    opt_parser.parse!(args)

    unless @puppetserver_wait_minutes > 0
      msg = "Invalid puppetserver wait minutes '#{@puppetserver_wait_minutes}'. Must be > 0"
      raise OptionParser::ParseError.new(msg)
    end
  end

  def prep_for_first_puppet_run
    info('Preparing for first set of puppet agent runs...', 'cyan')
    debug("Creating backup directory #{@bootstrap_backup}")
    FileUtils.mkdir(@bootstrap_backup)

    ensure_puppet_agent_stopped

    if @unsafe
      warn('SAFE mode has been disabled:', 'red.bold')
      warn(' - Interrupts will **NOT** be captured and ignored.', 'red.bold')
      warn(' - Any interrupts may cause system instability.', 'red.bold')
    else
      # From this point on, capture interrupts
      signals = ['INT','HUP','USR1','USR2']
      signals.each do |sig|
        Signal.trap(sig) { say "\nSafe mode enabled, ignoring interrupt - PID is #{Process.pid}".magenta }
      end
      info('Entering SAFE mode:', 'magenta.bold')
      info('  Interrupts will be captured and ignored to ensure bootstrap integrity.', 'magenta.bold')
    end

    # give user time to read the SAFE mode messages
    sleep(2)

    if @is_pe
      info('Puppet Enterprise found, preserving existing configuration.', 'cyan')
      info("  puppetserver is listening on port #{@initial_puppetserver_port}", 'cyan')
      @puppetserver_service = 'pe-puppetserver'
      @puppetdb_service = 'pe-puppetdb'
      @initial_puppetserver_port = '8140'
    else
      info('FOSS Puppet found. Change to bootstrap puppetserver configuration required.', 'cyan')
      @puppetserver_service = 'puppetserver'
      @puppetdb_service = 'puppetdb'

      # These items are all handled by the PE installer so need to be done for
      # the FOSS version independently.
      ensure_puppet_processes_stopped
      handle_existing_puppet_certs
      validate_site_puppet_code

      # The FOSS version will use 8150 and then switch to 8140 automatically if
      # all goes well. The server remaining on 8150 is an almost guaranteed
      # sign that something has gone wrong.
      @initial_puppetserver_port = '8150'
      configure_bootstrap_puppetserver
    end

    # Reload the puppetserver
    info('Reloading puppetserver', 'cyan')
    execute('puppetserver reload')
  end

  def print_closing_banner(linecounts)
    info('=== SIMP Bootstrap Finished! ===', 'yellow', '')
    info("Duration of complete bootstrap: #{Time.at(Time.now - @start_time).utc.strftime("%H:%M:%S")}")
    if !system('ps -C httpd > /dev/null 2>&1') && (linecounts.include?(-1) || (linecounts.uniq.length < linecounts.length))
      warn('Warning: Primitive checks indicate there may have been issues', 'magenta')
    end
    info("#{@logfile.path} contains details of the bootstrap actions performed.", 'yellow')
    info('Prior to operation, you must reboot your system.', 'magenta.bold')
    info('Run `puppet agent -t` after reboot to complete the bootstrap process.', 'magenta.bold')
    info('It may take a few **MINUTES** before the puppetserver accepts agent', 'magenta.bold')
    info('connections after boot.', 'magenta.bold')
  end

  def print_intro
    system('clear')
    info('=== Starting SIMP Bootstrap ===', 'yellow.bold', '')
    info("The log can be found at '#{@logfile.path}'\n")
  end

  # Checks if the puppetserver is running on the specified port
  def puppetserver_running?(port, quiet = false)
    unless quiet
      info("Checking if puppetserver is accepting connections on port #{port}", 'cyan')
    end
    curl_cmd = "curl -sS --cert #{Simp::Cli::Utils.puppet_info[:config]['hostcert']}" +
        " --key #{Simp::Cli::Utils.puppet_info[:config]['hostprivkey']} -k -H" +
        " \"Accept: s\" https://localhost:#{port}/production/certificate_revocation_list/ca"
    debug(curl_cmd) unless quiet
    running = (%x{#{curl_cmd} 2>&1} =~ /CRL/)
    running
  end

  def set_up_logger
    # Open log file
    logfilepath = File.dirname(File.expand_path(@bootstrap_log))
    FileUtils.mkpath(logfilepath) unless File.exists?(logfilepath)
    @logfile = File.open(@bootstrap_log, 'w')
  end

  # Track a running process by following its STDOUT output
  # Prints a '#' for each line of output
  # returns -1 if error occured, otherwise the line count if PTY.spawn succeeded
  def track_output(command, port = nil)
    ensure_puppetserver_running(port)
    successful = true

    debug('#' * 80, nil ,'')
    debug("Starting #{command}\n")

    start_time = Time.now
    linecount = 0
    col = ['green','red','yellow','blue','magenta','cyan']

    if @track
      info('Track => ', 'cyan')
      begin
        ::PTY.spawn(command) do |read, write, pid|
          begin
            read.each do |line|
              print ("#".send(col.first)) unless @verbose
              col.rotate!
              debug(line)
              linecount += 1
            end
          rescue Errno::EIO
          end
        end
      rescue PTY::ChildExited => e
        warn("#{command} exited unexpectedly:\n\t#{e.message}")
        successful = false
      #FIXME Pin down what exceptions are appropriate for this case!!!
      rescue
        # If we don't have a PTY, just run the command.
        debug('Running without a PTY!')
        output = %x{#{command}}
        debug(output)
        linecount = output.split("\n").length
        successful = false if $? != 0
      end
    else # don't track
      info("Running, please wait ... ")
      $stdout.flush
      output = Simp::Cli::Utils::show_wait_spinner {
        %x{#{command}}
      }
      debug(output)
      linecount = output.split("\n").length
      successful = false if $? != 0
    end
    puts
    debug("\n#{command} - Done!")
    end_time = Time.now
    debug("Duration of Puppet run: #{end_time - start_time} seconds")

    return successful ? linecount : -1
  end

  # Check various things on the host that could cause us trouble
  def validate_host_sanity
    info('Validating that the hostname is a FQDN', 'cyan')
    # Need to have a domain on the system
    if get_hostname.strip.split('.')[1..-1].empty?
      fail('Your system must have a fully qualified hostname of the form "<hostname>.<domain>"')
    end
  end

  # Do a quick validation that the code in the malleable SIMP spaces is not
  # going to cause the compilation to fail out of the box.
  def validate_site_puppet_code
    info('Validating site puppet code', 'cyan')

    errors = []

    env_dir = File.join(Simp::Cli::Utils.puppet_info[:config]['codedir'], 'environments', Simp::Cli::BOOTSTRAP_PUPPET_ENV)
    site_pp = File.join(env_dir, 'manifests','site.pp')

    if File.exist?(site_pp)
      msg = %x{puppet parser validate #{site_pp} 2>&1}
      unless $?.success?
        errors << msg.strip
      end
    end

    site_module = File.join(env_dir,'modules','site')

    if File.directory?(site_module)
      msg = %x{puppet parser validate #{site_module} 2>&1}
      unless $?.success?
        errors << msg.strip
      end
    end

    unless errors.empty?
      fail(
        "Puppet code validation failed\n" +
          "Please fix your manifests and try again\n" +
          "  * #{errors.join("\n  * ")}"
        )
    end
  end

  # verify bootstrap setup
  #
  # @raises if any bootstrap setup issue if found
  def verify_setup
    info('Verifying bootstrap setup...', 'cyan')
    validate_host_sanity
    check_for_start_lock
    check_for_simp_environment
  end

  #####################################################
  # general purpose methods
  # TODO consolidate with methods used by `simp config`
  #####################################################

  def execute(command)
    debug("Executing: #{command}")
    system(command)
  end

  # Debug logs only go to the console when verbose option specified,
  # but always go to the log file (which is expected to contain details)
  def debug(message, options=nil, console_prefix='> DEBUG: ')
    log_and_say("#{message}", options, console_prefix, @verbose)
  end

  def info(message, options=nil, console_prefix='> ')
    log_and_say("#{message}", options, console_prefix)
  end

  def warn(message, options=nil, console_prefix='> ')
    log_and_say("WARNING: #{message}", options, console_prefix)
  end

  def error(message, options='red.bold', console_prefix='> ')
    log_and_say("ERROR: #{message}", options, console_prefix)
  end

  def fail(message, options='red.bold', console_prefix='> ')
    log_and_say("ERROR: #{message}", options, console_prefix)
    raise Simp::Cli::ProcessingError.new("bootstrap processing terminated")
  end

  def log_and_say(message, options, console_prefix, log_to_console = true)
    log_prefix = Time.now.strftime('%Y-%m-%d %H:%M:%S') + ': '
    message.split("\n").each do |line|
      if @logfile
        @logfile.puts %{#{log_prefix}#{line}}
        @logfile.flush
      end

      if log_to_console
        if options.nil?
          say %{#{console_prefix}#{line}}
        else
          require 'shellwords'

          safe_line = Shellwords.escape(%{#{console_prefix}#{line}})
          eval(%{say "#{safe_line}".#{options}})
        end
      end
    end
  end
end
