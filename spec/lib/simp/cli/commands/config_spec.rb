require 'simp/cli/commands/config'
require 'spec_helper'
require 'fileutils'
require 'set'
require 'tmpdir'
require 'yaml'

def generate_input
  input_io = StringIO.new
  input_io                    <<
    "no\n"                    << # don't use FIPS (which CAN be applied as non-root user!)
    "\n"                      << # use suggested interface, as has to be a valid one
    "\n"                      << # activate the interface (default=yes)
    "\n"                      << # use DHCP (default=static IP)
    "puppet.test.local\n"     << # FQDN of this system
    "1.2.3.4\n"               << # IP addr of this system
    "255.255.255.0\n"         << # netmask of this system (default=255.255.255.0)
    "1.2.3.1\n"               << # gateway
    "1.2.3.10\n"              << # DNS servers
    "test.local\n"            << # DNS domain search string
    "\n"                      << # client networks (default=1.2.3.0/24)
    "time-a.nist.gov\n"       << # NTP time servers
    "1.2.3.11\n"              << # log servers
    "1.2.3.12\n"              << # failover log servers
    "\n"                      << # yum servers (default=["%{hiera('puppet::server')}])
    "\n"                      << # use auditd (default=yes)
    "\n"                      << # use iptables (default=yes)
    "\n"                      << # system runlevel (default=3)
    "\n"                      << # SELinux setting (default=enforcing)
    "\n"                      << # set GRUB password
    "no\n"                    << # don't auto-generate a password
    "Bz+oQg6OQWpNGO-hNR9hAr4PRlsOCwBG\n" << # GRUB password
    "Bz+oQg6OQWpNGO-hNR9hAr4PRlsOCwBG\n" << # confirm GRUB password
    "\n"                      << # master is a YUM server
    "\n"                      << # FQDN of puppet server
    "\n"                      << # puppet server IP
    "\n"                      << # Puppet Certificate Authority
    "\n"                      << # Puppet CA port (default=8141)
    "\n"                      << # use LDAP
    "\n"                      << # LDAP base DN
    "\n"                      << # LDAP bind DN
    "no\n"                    << # don't auto-generate a password
    "vsB2myX+l8-p-FOmbjG%%Exr0R3z8Mkm\n" << # LDAP bind password
    "vsB2myX+l8-p-FOmbjG%%Exr0R3z8Mkm\n" << # confirm LDAP bind password
    "\n"                      << # LDAP sync DN
    "no\n"                    << # don't auto-generate a password
    "6Pe4*3oW0Rw.VXx2BbdvfnU2bv9x*%CB\n" << # LDAP sync password
    "6Pe4*3oW0Rw.VXx2BbdvfnU2bv9x*%CB\n" << # confirm LDAP sync password
    "\n"                      << # LDAP root DN
    "\n"                      << # don't auto-generate a password
    "MCMD3u-iTXA8O6yCoDMotMGPTeHd7IGI\n" << # LDAP root password
    "MCMD3u-iTXA8O6yCoDMotMGPTeHd7IGI\n" << # confirm LDAP root password
    "\n"                      << # LDAP root master URI
    "\n"                      << # OpenLADAP server URIs
    "\n"                         # rsync root dir (default /srv/rsync)
  input_io.rewind
  input_io
end

def normalize(config_lines)
  # These config items whose values cannot be arbitrarily set
  # and/or vary each time they run.
  min_exclude_set = Set.new [
     '"network::interface"', # depends upon actual interfaces available
     '"grub::password"',     # hash value that varies from run-to-run with same password
     '"ldap::bind_hash"',    # hash value that varies from run-to-run with same password
     '"ldap::sync_hash"',    # hash value that varies from run-to-run with same password
     '"ldap::root_hash"'     # hash value that varies from run-to-run with same password
  ]

  # FIXME This is fragile. Really should use a yaml parser.
  normalized_config = []
  config_lines.each do |line|
    next if line[0]=='#' or line.strip.empty?
    key = line.split(': ')[0].strip
    next if min_exclude_set.include?(key)
    normalized_config << line
  end
   normalized_config
end

describe Simp::Cli::Commands::Config do
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }

  describe ".run" do
    before :each do
      @input = generate_input
      @output = StringIO.new
      @prev_terminal = $terminal
      $terminal = HighLine.new(@input, @output)
      @tmp_dir     = Dir.mktmpdir( File.basename( __FILE__ ) )
      @output_file = File.join(@tmp_dir, 'simp.yaml')
      Simp::Cli::Commands::Config.reset_options
    end

    after :each do
      @input.close
      @output.close
      $terminal = @prev_terminal
      FileUtils.remove_entry_secure @tmp_dir
      Facter.reset  # make sure this test's facts don't affect other tests
    end

    it "creates valid simp.yaml for non-root user interactively" do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
      begin
        Simp::Cli::Commands::Config.run(['-o', @output_file])
      rescue Exception =>e
        puts "=========stdout========="
        puts @output.string
        raise
      end
      expect( File.exists?( @output_file ) ).to be true

      # normalize out lines that are not deterministic
      expected = normalize(IO.readlines(File.join(files_dir, 'simp.yaml')))
      actual = normalize(IO.readlines(@output_file))
      expect( actual ).to eq expected
    end

    it "creates valid simp.yaml for non-root user using minimal prompts" do
      skip("FIXME: test will not run in all environments")
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'

      #FIXME The input below ASSUMES the use_ldap default will be yes.
      input_string = ""
      input_string << "no\n"                    << # don't auto-generate a password
                "Bz+oQg6OQWpNGO-hNR9hAr4PRlsOCwBG\n" << # GRUB password
                "Bz+oQg6OQWpNGO-hNR9hAr4PRlsOCwBG\n" << # confirm GRUB password
                "no\n"                    << # don't auto-generate a password
                "vsB2myX+l8-p-FOmbjG%%Exr0R3z8Mkm\n" << # LDAP bind password
                "vsB2myX+l8-p-FOmbjG%%Exr0R3z8Mkm\n" << # confirm LDAP bind password
                "no\n"                    << # don't auto-generate a password
                "6Pe4*3oW0Rw.VXx2BbdvfnU2bv9x*%CB\n" << # LDAP sync password
                "6Pe4*3oW0Rw.VXx2BbdvfnU2bv9x*%CB\n" << # confirm LDAP sync password
                "\n"                      << # don't auto-generate a password
                "MCMD3u-iTXA8O6yCoDMotMGPTeHd7IGI\n" << # LDAP root password
                "MCMD3u-iTXA8O6yCoDMotMGPTeHd7IGI\n"    # confirm LDAP root password
      @input.reopen(input_string)
      @input.rewind

      begin
        Simp::Cli::Commands::Config.run(['-o', @output_file, '-f'])
      rescue EOFError => e
        puts @output.string
        raise
      end
      expect( File.exists?( @output_file ) ).to be true

      #FIXME Need to determine system defaults to generate an expected simp.yaml file.
    end

    it "creates valid simp.yaml using existing file, command line overrides, and prompts" do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
      input_string = "\n" # use suggested interface, as has to be a valid one
      @input.reopen(input_string)
      @input.rewind
      begin
        Simp::Cli::Commands::Config.run(['-o', @output_file, '--apply-with-questions',
           File.join(files_dir, 'prev_simp.yaml'), 'use_iptables=false',
          'dns::servers=1.2.3.10,,1.2.3.11,,1.2.3.12'])
      rescue Exception =>e
        puts "=========stdout========="
        puts @output.string
        raise
      end
      expect( File.exists?( @output_file ) ).to be true

      # normalize out lines that are not deterministic
      expected = normalize(IO.readlines(File.join(files_dir, 'simp_with_overrides.yaml')))
      actual = normalize(IO.readlines(@output_file))
      expect( actual ).to eq expected
    end

    it "does not apply actions when user is not root" do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
      begin
        Simp::Cli::Commands::Config.run(['-o', @output_file])
      rescue Exception =>e
        puts "=========stdout========="
        puts @output.string
        raise
      end

      skip_lines = @output.string.split("\n").delete_if do |line|
        !line.include?("skipping apply [**user is not root**]")
      end

      fmt_begin = "\e[35m\e[1m"
      fmt_end = "\e[0m"
      expected_lines = [
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} network::conf",
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} hostname::conf",
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} grub::password",
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} certificates",
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} puppet::rename_fqdn_yaml",
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} yum::repositories",
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} puppet::autosign",
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} puppet::conf",
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} puppet::hosts_entry",
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} puppet::add_ldap_to_hiera",
        "#{fmt_begin}(skipping apply [**user is not root**] )#{fmt_end} yaml::production_file_writer"
      ]

      expect(skip_lines).to eq expected_lines
    end

    it "prints a summary of actions" do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
      begin
        Simp::Cli::Commands::Config.run(['-o', @output_file])
      rescue Exception =>e
        puts "=========stdout========="
        puts @output.string
        raise
      end

      summary = @output.string.split('Summary of Applied Changes')[1]
      expect(summary).to match /No digest algorithm adjustment necessary since FIPS is not enabled/m
      expect(summary).to match /Configuration of a network interface skipped/m
      expect(summary).to match /Setting of hostname skipped/m
      expect(summary).to match /Setting of GRUB password skipped/m
      expect(summary).to match /FakeCA certificate generation for SIMP skipped/m
      expect(summary).to match /Rename of puppet.your.domain.yaml template to <host>.yaml skipped/m
      expect(summary).to match /YUM Update repo configuration and update to simp::yum::enable_simp_repos in <host>.yaml skipped/m
      expect(summary).to match /Setup of autosign in \/etc\/puppet\/autosign.conf skipped/m
      expect(summary).to match /Update to Puppet settings in \/etc\/puppet\/puppet.conf skipped/m
      expect(summary).to match /Update to \/etc\/hosts to ensure puppet server entries exist skipped/m
      expect(summary).to match /Addition of simp::ldap_server to <host>.yaml skipped/m

      # The prefix of this path is going to depend explicitly on where Puppet
      # is installed on your system since this is not hard coded in the
      # environment.
      expect(summary).to match /Creation of .*\/environments\/simp\/hieradata\/simp_def.yaml skipped/m
      expect(summary).to match /#{@output_file} created/m
    end

    it "does not create a yaml file when --dry-run" do
      begin
        Simp::Cli::Commands::Config.run(['--dry-run', '-o', @output_file])
      rescue Exception =>e
        puts "=========stdout========="
        puts @output.string
        raise
      end
      expect( File.exists?( @output_file ) ).to be false
    end

    it "does prompt user when --dry-run" do
      begin
        Simp::Cli::Commands::Config.run(['--dry-run', '-o', @output_file])
      rescue Exception =>e
        puts "=========stdout========="
        puts @output.string
        raise
      end

      recommended_output_lines = @output.string.split("\n").delete_if do |line|
         !line.include?(' - recommended value:')
      end
      if (recommended_output_lines.empty?)
        puts @output.string
      end
      expect(recommended_output_lines).not_to be_empty
    end

    it "raises an RuntimeError when noninteractive and input yaml is incomplete" do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'

      expect {  Simp::Cli::Commands::Config.run(['-o', @output_file, '--apply',
        File.join(files_dir, 'prev_simp.yaml')]) }.to raise_error(RuntimeError,
          "FATAL: no answer for 'network::interface'")
    end

    it "raises an RuntimeError when noninteractive and input yaml has an invalid value" do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'

      # Since network::interface value fails validation when read in, that value
      # is skipped. This results in a missing anwer for network::interface.
      expect {  Simp::Cli::Commands::Config.run(['-o', @output_file, '--apply',
        File.join(files_dir, 'bad_simp.yaml') ]) }.to raise_error(RuntimeError,
          "FATAL: no answer for 'network::interface'")
    end
  end

  describe ".read_answers_file" do
    before :each do
      @tmp_dir   = Dir.mktmpdir( File.basename( __FILE__ ) )
      @yaml_file = File.join(@tmp_dir, 'answers.yaml')
    end

    after :each do
      FileUtils.chmod 0777, @yaml_file if File.exists?(@yaml_file)
      FileUtils.remove_entry_secure @tmp_dir
    end

    it "raises exception when file to parse cannot be accessed" do
      expect { Simp::Cli::Commands::Config.read_answers_file('oops.yaml') }.to raise_error(
        RuntimeError, "Could not access the file 'oops.yaml'!")
    end

    it "returns hash when file contains valid yaml" do
      File.open(@yaml_file, 'w') do |file|
        file.puts("dhcp: static")
        file.puts("hostname: puppet.test.local")
        file.puts("ipaddress: \"1.2.3.4\"")
        file.puts("netmask: \"255.255.255.0\"")
        file.puts("gateway: \"1.2.3.1\"")
        file.puts("\"dns::servers\":")
        file.puts("  - \"1.2.3.10\"")

      end
      expected = {
        "dhcp" => "static",
        "hostname" => "puppet.test.local",
        "ipaddress" => "1.2.3.4",
        "netmask" => "255.255.255.0",
        "gateway" => "1.2.3.1",
        "dns::servers" => ["1.2.3.10"]
      }
      expect( Simp::Cli::Commands::Config.read_answers_file(@yaml_file) ).to eq expected
    end

    it "returns empty hash when file is empty" do
      FileUtils.touch(@yaml_file)
      expected = {}
      expect( Simp::Cli::Commands::Config.read_answers_file(@yaml_file) ).to eq expected
    end

    it "returns empty hash when file is only comments" do
      File.open(@yaml_file, 'w') do |file|
        file.puts('#')
        file.puts('# This file contains only yaml comments')
        file.puts('#')
      end
      expected = {}
      FileUtils.touch(@yaml_file)
      expected = {}
      expect( Simp::Cli::Commands::Config.read_answers_file(@yaml_file) ).to eq expected
    end

    it "raises exception when file contains malformed yaml" do
      File.open(@yaml_file, 'w') do |file|
        file.puts('====')
        file.puts('use_fips:')
      end
      expect { Simp::Cli::Commands::Config.read_answers_file(@yaml_file) }.to raise_error(
        RuntimeError, /System configuration file '#{@yaml_file}' is corrupted/)
    end
  end
end
