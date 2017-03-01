require 'pty'
require 'timeout'
require 'facter'
require 'highline/import'

  # Ensure the puppetserver is running ca on the specified port.
  # Used ensure the puppetserver service is running.
  def ensure_running(port = nil)
    port ||= `puppet config print masterport`.chomp

    begin
      say "> <%= color('Waiting for puppetserver to accept connections on port #{port}', :cyan) %>"
      curl_cmd = "curl -sS --cert #{::Utils.puppet_info[:config]['certdir']}/`hostname`.pem --key #{::Utils.puppet_info[:config]['ssldir']}/private_keys/`hostname`.pem -k -H \"Accept: s\" https://localhost:#{port}/production/certificate_revocation_list/ca"
      say "> INFO: #{curl_cmd}" if @verbose
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
  def track_output(command, port = nil)
    say "> INFO: #{command}" if @verbose
    ensure_running(port)
    successful = true

    @logfile.print '#' * 80
    @logfile.puts("\nStarting #{command}\n")

    start_time = Time.now
    linecount = 0
    col = ['red','green','yellow','blue','magenta','cyan']

    if @track
      say "> <%= color('Track => ', :cyan) %>"
      begin
        ::PTY.spawn("#{command}") do |read, write, pid|
          begin
            read.each do |line|
              print ("#".send(col.first))
              col.shuffle!
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
    say "> INFO: Duration of Puppet run: #{end_time - start_time} seconds" if @verbose
    @logfile.puts("Duration of Puppet run: #{end_time - start_time} seconds")

    return successful ? linecount : -1
  end
