module Simp::Cli::Commands; end

require 'simp/cli/config/items/action/set_production_to_simp_action'

class Simp::Cli::Commands::Bootstrap < Simp::Cli
  require 'pty'
  require 'timeout'
  require 'facter'
  require File.expand_path( '../defaults', File.dirname(__FILE__) )
  BOOTSTRAP_LOG = File.join(SIMP_CLI_HOME, 'simp_bootstrap.log')

  @verbose = false
  @track = true
  @opt_parser = OptionParser.new do |opts|
    opts.banner = "\n=== The SIMP Bootstrap Tool ==="
    opts.separator "\nThe SIMP Bootstrap Tool aids initial configuration of the system by"
    opts.separator "bootstrapping it. This should be run after 'simp config' has applied a new"
    opts.separator "system configuration."
    opts.separator ""
    opts.separator "Logging information about the run is written to #{BOOTSTRAP_LOG}"
    opts.separator ""
    opts.separator "OPTIONS:\n"

    opts.on("-v", "--[no-]verbose", "Enables/disables verbose mode. Prints out verbose information.") do |v|
      @verbose = v
    end

    opts.on("-t", "--[no-]track", "Enables/disables the tracker. Default is enabled.") do |t|
      @track = t
    end

    opts.on("-h", "--help", "Print out this message.") do
      puts opts
      @help_requested = true
    end
  end


  # Ensure the puppetserver is running ca on the specified port.
  # Used ensure the puppetserver service is running.
  def self.ensure_running(port = nil)
    port ||= `puppet config print masterport`.chomp

    begin
      running = (%x{curl -sS --cert #{::Utils.puppet_info[:config]['certdir']}/`hostname`.pem --key #{::Utils.puppet_info[:config]['ssldir']}/private_keys/`hostname`.pem -k -H "Accept: s" https://localhost:#{port}/production/certificate_revocation_list/ca 2>&1} =~ /CRL/)
      unless running
        system('puppet resource service puppetserver ensure="running" enable=true > /dev/null 2>&1 &')
        stages = %w{. o O @ *}
        rest = 0.4
        timeout = 5

        Timeout::timeout(timeout*60) {
          while not running do
            running = (%x{curl -sS --cert #{::Utils.puppet_info[:config]['certdir']}/`hostname`.pem --key #{::Utils.puppet_info[:config]['ssldir']}/private_keys/`hostname`.pem -k -H "Accept: s" https://localhost:#{port}/production/certificate_revocation_list/ca 2>&1} =~ /CRL/)
            stages.each{ |x|
              $stdout.flush
              print "Waiting for Puppet Server to Start, on port #{port}  " + x + "\r"
              sleep(rest)
            }
          end
        }
        $stdout.flush
        puts
      end
    rescue Timeout::Error
      fail("The Puppet Server did not start within #{timeout} minutes. Please start puppetserver by hand and inspect any issues.")
    end
  end

  # Track a running process by following its STDOUT output
  # Prints a '#' for each line of output
  # returns -1 if error occured, otherwise the line count if PTY.spawn succeeded
  def self.track_output(command, port = nil)
    ensure_running(port)
    successful = true

    @logfile.print '#' * 80
    @logfile.puts("\nStarting #{command}\n")

    start_time = Time.now
    linecount = 0
    if @track
      print 'Track => '
      begin
        ::PTY.spawn("#{command}") do |read, write, pid|
          begin
            read.each do |line|
              print '#'
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
      print "Running, please wait ... "
      $stdout.flush
      output = %x{#{command}}
      @logfile.puts output
      linecount = output.split("\n").length
      successful = false if $? != 0
    end
    puts " Done!"
    @logfile.puts("\n#{command} - Done!")
    end_time = Time.now
    puts "Duration of Puppet run: #{end_time - start_time} seconds" if @verbose
    @logfile.puts("Duration of Puppet run: #{end_time - start_time} seconds")

    return successful ? linecount : -1
  end

  def self.run(args = [])
    super
    return if @help_requested

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
    puts
    puts "*** Starting SIMP Bootstrap ***"
    puts "   If this runs quickly, something wrong happened. To debug the problem,"
    puts "   run 'puppet agent --test' by hand or read the log. The log can be found"
    puts "   at '#{@logfile.path}'."
    puts

    # Kill all puppet processes and stop specific services
    puts "Killing all Puppet processes, httpd and removing Puppet ssl certs.\n\n" if @verbose
    system("pkill -9 -f puppetmasterd >& /dev/null")
    system("pkill -9 -f puppet >& /dev/null")
    system('pkill -f pserver_tmp')
    system("puppet resource service puppetserver ensure=stopped >& /dev/null")
    system("puppet resource service httpd ensure=stopped >& /dev/null")
    FileUtils.rm_rf(Dir.glob(File.join(::Utils.puppet_info[:config]['ssldir'],'*')))
    FileUtils.rm_f(Dir.glob(File.join(::Utils.puppet_info[:config]['rundir'],'*')))
    FileUtils.touch('/.autorelabel')

    puts "*** Starting the Puppetmaster ***"
    puts

    FileUtils.mkdir_p("#{::Utils.puppet_info[:config]['vardir']}/pserver_tmp")
    FileUtils.chown('puppet','puppet',"#{::Utils.puppet_info[:config]['vardir']}/pserver_tmp")
    system(%{puppet resource simp_file_line puppetserver path='/etc/sysconfig/puppetserver' match='^JAVA_ARGS' line='JAVA_ARGS="-Xms2g -Xmx2g -XX:MaxPermSize=256m -Djava.io.tmpdir=#{::Utils.puppet_info[:config]['vardir']}/pserver_tmp"' 2>&1 > /dev/null})

    if File.directory?('/etc/puppetlabs/puppetserver/conf.d')
      puppetserver_dir = '/etc/puppetlabs/puppetserver/conf.d'
    else
      puppetserver_dir = '/etc/puppetserver/conf.d'
    end

    if File.directory?(puppetserver_dir)
      system(%{puppet resource simp_file_line puppetserver path='#{puppetserver_dir}/webserver.conf' match='^\\s*ssl-host' line='    ssl-host = 0.0.0.0' 2>&1 > /dev/null})
      system(%{puppet resource simp_file_line puppetserver path='#{puppetserver_dir}/webserver.conf' match='^\\s*ssl-port' line='    ssl-port = 8150' 2>&1 > /dev/null})
    end

    puts

    puppet_major_version = `puppet --version`.chomp.split('.').first
    # Define the puppet command call and the run command options
    pupcmd = 'puppet agent --onetime --no-daemonize --no-show_diff --verbose --no-splay --masterport=8150 --ca_port=8150'
    if puppet_major_version == '3'
      pupcmd += " --pluginsync"
    end

    # Firstrun is tagged and run against the default puppetserver port, 8150.
    # This run will configure puppetserver and puppetdb; all subsequent runs
    # will run against the conifgured masterport.
    puts "Running puppet agent, with tags pupmod,simp\n"
    linecounts << track_output("#{pupcmd} --tags pupmod,simp 2> /dev/null", '8150')
    puts

    # If selinux is enabled, relabel the filesystem.
    if Facter.value(:selinux) && !Facter.value(:selinux_current_mode).nil? && (Facter.value(:selinux_current_mode) != "disabled")
      puts "Relabeling filesystem for selinux...\n"
      @logfile.puts("Relabeling filesystem for selinux.\n")
      system("fixfiles -f relabel >> #{@logfile.path} 2>&1")
    end

    # SIMP is not single-run idempotent.  Until it is, run puppet twice.
    puts "\nRunning puppet without tags"
    pupcmd = "puppet agent --onetime --no-daemonize --no-show_diff --verbose --no-splay"
    if puppet_major_version == '3'
      pupcmd += " --pluginsync"
    end
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
      puts e
      puts "The Puppet Server process running on port 8150 could not be killed. Please check your configuration!"
    end

    # Print closing banner
    puts
    puts "*** SIMP Bootstrap Complete! ***"
    puts "Duration of complete bootstrap: #{Time.now - bootstrap_start_time} seconds" if @verbose

    if !system('ps -C httpd > /dev/null 2>&1') && (linecounts.include?(-1) || (linecounts.uniq.length < linecounts.length))
      puts "   \033[1mWarning\033[0m: Primitive checks indicate there may have been issues."
      puts "   Check '#{@logfile.path}' for details."
      puts "   Please run 'puppet agent -t' by hand to debug your configuration."
    else
      puts
      puts "You should \033[1mreboot\033[0m your system to ensure consistency at this point."
    end
    puts
  end
end
