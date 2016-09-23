module Simp::Cli::Commands; end

class Simp::Cli::Commands::Bootstrap < Simp::Cli
  require 'pty'
  require 'timeout'
  require 'facter'

  @verbose = false
  @track = true
  @opt_parser = OptionParser.new do |opts|
    opts.banner = "\n=== The SIMP Bootstrap Tool ==="
    opts.separator "\nThe SIMP Bootstrap Tool aids initial configuration of the system by"
    opts.separator "bootstrapping it. This should be run after 'simp config' has applied a new"
    opts.separator "system configuration."
    opts.separator ""
    opts.separator "Logging information about the run is written to ~/.simp/simp_bootstrap.log"
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
    if port == nil
      port = `puppet config print ca_port`.strip
    end
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
              print "Waiting for Puppet Server to Start  " + x + "\r"
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

    bootstrap_start_time = Time.now

    # Set us up to use the SIMP environment. Be careful to preserve the
    # existing 'production' environment if one exists.
    environment_path = ::Utils.puppet_info[:simp_environment_path]

    fail("Could not find the simp environment path at #{environment_path}") unless File.directory?(environment_path)

    Dir.chdir(File.dirname(environment_path)) do
      File.directory?('simp')

      if File.exist?('production')
        if File.symlink?('production')
          unless File.readlink('production') == 'simp'
            FileUtils.mv('production',"pre_simp_production_#{bootstrap_start_time.to_i}")
          end
        else
            FileUtils.mv('production',"pre_simp_production_#{bootstrap_start_time.to_i}")
        end
      end

      FileUtils.ln_s('simp','production') unless File.exist?('production')
    end

    linecounts = Array.new

    # Open log file
    logfilepath = File.expand_path('~/.simp/simp_bootstrap.log')
    FileUtils.mkpath(File.dirname(logfilepath)) unless File.exists?(logfilepath)
    @logfile = File.open(logfilepath, 'w')

    # Define the puppet command call and the run command options
    pupcmd = 'puppet agent --pluginsync --onetime --no-daemonize --no-show_diff --verbose --no-splay --masterport=8150 --ca_port=8150'
    pupruns = [
      'pki,stunnel,concat',
      'firstrun,concat',
      'rsync,concat,apache,iptables',
      'user',
      'group'
    ]

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

    system(%{puppet resource simp_file_line puppetserver path='#{puppetserver_dir}/webserver.conf' match='^\\s*ssl-host' line='    ssl-host = 0.0.0.0' 2>&1 > /dev/null})
    system(%{puppet resource simp_file_line puppetserver path='#{puppetserver_dir}/webserver.conf' match='^\\s*ssl-port' line='    ssl-port = 8150' 2>&1 > /dev/null})

    puts

    puts "Beginning Puppet agent runs ..."
    pupruns.each do |puprun|
      puts "... with tag#{puprun.include?(',') ? 's' : ''} '#{puprun}'"
      linecounts << track_output("#{pupcmd} --tags #{puprun} 2> /dev/null", '8150')
    end

    puts

    if Facter.value(:selinux) && !Facter.value(:selinux_current_mode).nil? && (Facter.value(:selinux_current_mode) != "disabled")
      puts 'Relabeling filesystem for selinux...'
      @logfile.puts('Relabeling filesystem for selinux.')
      system("fixfiles -f relabel >> #{@logfile.path} 2>&1")
    end

    puts "*** Running Puppet Finalization ***"
    puts

    # First run of puppet without tags will configure puppetserver, causing
    # a refresh of the puppetserver service.
    track_output("#{pupcmd}",'8150')

    # From this point on, run puppet without specifying the masterport since
    # puppetserver is configured.
    pupcmd = "puppet agent --pluginsync --onetime --no-daemonize --no-show_diff --verbose --no-splay"

    # Run puppet agent up to 3X to get slapd running (unless it already is)
    # If this fails, LDAP is probably not configured right
    i = 0
    while (i < 3) && !system('/bin/ps -C slapd >& /dev/null') do
      # No longer running puppet against 8150.
      track_output("#{pupcmd}")
      i = i + 1
    end
    if (i == 3) && $use_ldap
      puts "   \033[1mWarning\033[0m: It does not look like LDAP was properly configured to start."
      puts "   Please check your configuration."
    else
      # At this point, we should be connected to LDAP properly.
      # Run puppet up to 3 additional times if we can't verify that we're actually connected!
      j = 0
      while (j < 3) && !system('getent group administrators >& /dev/null') do
        track_output("#{pupcmd}")
        j = j + 1
      end
      if j == 3
        puts "   \033[1mWarning\033[0m: Could not find the administrators group."
        puts "   Please check your configuration."
      end
      puts "Puppet Finalization - Done!"
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

    if !system('ps -C httpd 2>&1 > /dev/null') && (linecounts.include?(-1) || (linecounts.uniq.length < linecounts.length))
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
