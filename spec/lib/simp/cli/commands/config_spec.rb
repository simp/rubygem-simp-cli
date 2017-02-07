require 'spec_helper'
require 'simp/cli/commands/config'
require 'fileutils'
require 'set'
require 'yaml'

# Create StringIO corresponding to user input for the simp
# scenario in which the default values are accepted.
# FIXME:  This input is INCORRECT if /etc/yum.repos.d/simp_filesystem.repo exists.
def generate_simp_input_accepting_defaults
  input_io = StringIO.new
  input_io                        <<
    "\n"                          << # when empty defaults to 'simp' scenario
    "\n"                          << # use suggested interface, as has to be a valid one
    "\n"                          << # activate the interface
    "\n"                          << # static IP
    "\n"                          << # FQDN of this system
    "\n"                          << # IP addr of this system
    "\n"                          << # netmask of this system
    "\n"                          << # gateway
    "\n"                          << # DNS servers
    "\n"                          << # DNS domain search string
    "\n"                          << # trusted networks
    "\n"                          << # NTP time servers
    "\n"                          << # set GRUB password
    "\n"                          << # auto-generate GRUB password
    "\n"                          << # Press enter to continue
    "\n"                          << # set production env to simp
    "1.2.3.6\n"                   << # external YUM servers (assuming no simp_filesystem.repo)
    "http://os/path\n"            << # YUM OS update url
    "http://simp/path\n"          << # YUM SIMP update url
    "\n"                          << # SIMP is LDAP server
    "\n"                          << # LDAP base DN
    "\n"                          << # don't auto-generate a password
    "iTXA8O6yCoDMotMGPTeHd7IGI\n" << # LDAP root password
    "iTXA8O6yCoDMotMGPTeHd7IGI\n" << # confirm LDAP root password
    "\n"                             # log servers
  input_io.rewind
  input_io
end

# Create StringIO corresponding to user input for the simp-lite
# scenario in which the most values are set to user-provided values.
# Exercises LDAP-enabled, but non-LDAP server logic.
# FIXME:  This input is INCORRECT if /etc/yum.repos.d/simp_filesystem.repo exists.
def generate_simp_input_setting_values(scenario = 'simp-lite')
  input_io = StringIO.new
  input_io                                    <<
    "simp-lite\n"                             << # 'simp-lite' scenario
    "\n"                                      << # use suggested interface, as has to be a valid one
    "no\n"                                    << # don't activate the interface
    "simp.test.local\n"                       << # FQDN of this system
    "1.2.3.4\n"                               << # IP addr of this system
    "255.255.255.0\n"                         << # netmask of this system
    "1.2.3.1\n"                               << # gateway
    "1.2.3.10\n"                              << # DNS servers
    "test.local\n"                            << # DNS domain search string
    "1.2.0.0/16\n"                            << # trusted networks
    "time-a.nist.gov\n"                       << # NTP time servers
    "no\n"                                    << # don't set the GRUB password
    "no\n"                                    << # don't set production env to simp
    "1.2.3.6\n"                               << # external YUM servers (assuming no simp_filesystem.repo)
    "http://os/path\n"                        << # YUM OS update url
    "http://simp/path\n"                      << # YUM SIMP update url
    "no\n"                                    << # SIMP is not LDAP server
    "dc=test,dc=local\n"                      << # LDAP base DN
    "cn=hostAuth,ou=Hosts,dc=test,dc=local\n" << # LDAP bind DN
    "vsB2myX+l8-p-FOmbjG%%Exr0R3z8Mkm\n"      << # LDAP bind password
    "vsB2myX+l8-p-FOmbjG%%Exr0R3z8Mkm\n"      << # confirm LDAP bind password
    "\n"                                      << # don't auto-generate a password
    "MCMD3u-iTXA8O6yCoDMotMGPTeHd7IGI\n"      << # LDAP root password
    "MCMD3u-iTXA8O6yCoDMotMGPTeHd7IGI\n"      << # confirm LDAP root password
    "ldap://puppet.test.local\n"              << # LDAP root master URI
    "ldap://puppet.test.local\n"              << # OpenLDAP server URIs
    "1.2.3.11\n"                              << # log servers
    "1.2.3.12\n"                                 # failover log servers
  input_io.rewind
  input_io
end

# Create StringIO corresponding to user input for the 'poss'
# scenario in which most values are set to user-provided values.
# Exercises LDAP-disabled and SSSD-disabled logic.
# via user input.
# FIXME:  This input is INCORRECT if /etc/yum.repos.d/simp_filesystem.repo exists.
def generate_poss_input_setting_values
  input_io = StringIO.new
  input_io                <<
    "poss\n"              << # 'poss' scenario
    "\n"                  << # use suggested interface, as has to be a valid one
    "no\n"                << # don't activate the interface
    "simp.test.local\n"   << # FQDN of this system
    "1.2.3.4\n"           << # IP addr of this system
    "255.255.255.0\n"     << # netmask of this system
    "1.2.3.1\n"           << # gateway
    "1.2.3.10\n"          << # DNS servers
    "test.local\n"        << # DNS domain search string
    "1.2.0.0/16\n"        << # trusted networks
    "time-a.nist.gov\n"   << # NTP time servers
    "no\n"                << # don't set the GRUB password
    "no\n"                << # don't set production env to simp
    "1.2.3.4 1.2.3.5\n"   << # external YUM servers (assuming no simp_filesystem.repo)
    "http://os/path\n"    << # YUM OS update url
    "http://simp/path\n"  << # YUM SIMP update url
    "no\n"                << # don't use LDAP
    "no\n"                << # use SSSD
    "1.2.3.11\n"          << # log servers
    "1.2.3.12\n"             # failover log servers
  input_io.rewind
  input_io
end

def normalize(file, other_keys_to_exclude = [])
  # These config items whose values cannot be arbitrarily set
  # and/or vary each time they run.
  min_exclude_set = Set.new [
     'simp_options::fips',            # set by FIPS mode on running system which we can't control
     'cli::network::interface',       # depends upon actual interfaces available
     'grub::password',                # hash value that varies from run-to-run with same password
     'simp_options::ldap::bind_hash', # hash value that varies from run-to-run with same password
     'simp_options::ldap::sync_hash', # hash value that varies from run-to-run with same password
     'simp_options::ldap::root_hash'  # hash value that varies from run-to-run with same password
  ]

  exclude_set = min_exclude_set.merge(other_keys_to_exclude)

  yaml_hash = YAML.load(File.read(file))
  yaml_hash = {} if !yaml_hash.is_a?(Hash) # empty yaml file returns false
  exclude_set.each do |key|
    yaml_hash[key] = 'value normalized' if yaml_hash.key?(key)
  end
  yaml_hash
end

describe Simp::Cli::Commands::Config do
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }

  before(:each) do
    @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__) )

    allow(::Utils).to receive(:puppet_info).and_return( {
      :config => {
        'codedir' => @tmp_dir,
        'confdir' => @tmp_dir
      },
      :environment_path => File.join(@tmp_dir, 'environments'),
      :simp_environment_path => File.join(@tmp_dir, 'environments', 'simp'),
      :fake_ca_path => File.join(@tmp_dir, 'environments', 'simp', 'FakeCA')
    } )
    FileUtils.cp_r(File.join(files_dir, 'environments'), @tmp_dir)
  end

  describe '.run' do

    let(:extra_keys_to_exclude) { [
        'cli::network::gateway',
        'cli::network::hostname',
        'cli::network::ipaddress',
        'cli::network::netmask',
        'cli::puppet::server::ip',
        'simp_options::dns::servers',
        'simp_options::dns::search',
        'simp_options::ldap::base_dn',
        'simp_options::ldap::bind_pw',
        'simp_options::ldap::master',
        'simp_options::ldap::sync_pw',
        'simp_options::ldap::uri',
        'simp_options::puppet::ca',
        'simp_options::puppet::server',
        'simp_options::trusted_nets'
     ] }

    before :each do
      @input = StringIO.new
      @output = StringIO.new
      @prev_terminal = $terminal
      $terminal = HighLine.new(@input, @output)
      @answers_output_file = File.join(@tmp_dir, 'simp_conf.yaml')
      @puppet_system_file = File.join(@tmp_dir, 'simp_config_settings.yaml')
      @log_file = File.join(@tmp_dir, 'simp_config.log')
      Simp::Cli::Commands::Config.reset_options
    end

    after :each do
      @input.close
      @output.close
      $terminal = @prev_terminal
      FileUtils.remove_entry_secure @tmp_dir
      Facter.reset  # make sure this test's facts don't affect other tests
    end

    context 'non-root user' do

     it "creates valid yaml files for 'simp' scenario, interactively accepting all defaults" do
       skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
       @input.reopen(generate_simp_input_accepting_defaults)
       begin
         Simp::Cli::Commands::Config.run(['-o', @answers_output_file,
           '-p', @puppet_system_file, '-l', @log_file])
       rescue Exception =>e
         puts '=========stdout========='
         puts @output.string
         raise
       end
       expect( File.exists?( @answers_output_file ) ).to be true

       # normalize out YAML keys that are not deterministic
       expected = normalize(File.join(files_dir, 'simp_conf_accepting_defaults_simp_scenario.yaml'), extra_keys_to_exclude)
       actual_simp_conf = normalize(@answers_output_file, extra_keys_to_exclude)
       expect( actual_simp_conf ).to eq expected
     end

     it "creates valid output yaml files for 'simp-lite' scenario, interactively setting values" do
       skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
       @input.reopen(generate_simp_input_setting_values('simp-lite'))
       begin
         Simp::Cli::Commands::Config.run(['-o', @answers_output_file,
           '-p', @puppet_system_file, '-l', @log_file])
       rescue Exception =>e
         puts '=========stdout========='
         puts @output.string
         raise
       end
       expect( File.exists?( @answers_output_file ) ).to be true

       # normalize out YAML keys that are not deterministic
       expected = normalize(File.join(files_dir, 'simp_conf_setting_values_simp_lite_scenario.yaml'))
       actual_simp_conf = normalize(@answers_output_file)
       expect( actual_simp_conf ).to eq expected
     end

     it "creates valid output yaml files for 'poss' scenario, interactively setting values " do
       skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
       @input.reopen(generate_poss_input_setting_values)
       begin
         Simp::Cli::Commands::Config.run(['-o', @answers_output_file,
           '-p', @puppet_system_file, '-l', @log_file])
       rescue Exception =>e
         puts '=========stdout========='
         puts @output.string
         raise
       end
       expect( File.exists?( @answers_output_file ) ).to be true

       # normalize out YAML keys that are not deterministic
       expected = normalize(File.join(files_dir, 'simp_conf_setting_values_poss_scenario.yaml'))
       actual_simp_conf = normalize(@answers_output_file)
       expect( actual_simp_conf ).to eq expected
     end

     it 'creates valid output yaml files for user using minimal prompts' do
       skip("Test can't be run as root") if ENV.fetch('USER') == 'root'

       input_string = ''
       input_string << "simp-lite\n"          << # 'simp-lite' scenario
                 "1.2.3.6\n"                  << # external YUM servers (assuming no simp_filesystem.repo)
                 "http://os/path\n"           << # YUM OS update url
                 "http://simp/path\n"         << # YUM SIMP update url
                 "\n"                         << # don't auto-generate LDAP root password
                 "iTXA8O6yCoDMotMGTeHd7IGI\n" << # LDAP root password
                 "iTXA8O6yCoDMotMGTeHd7IGI\n"    # confirm LDAP root password
       @input.reopen(input_string)
       @input.rewind

       begin
         Simp::Cli::Commands::Config.run(['-o', @answers_output_file,
           '-p', @puppet_system_file, '-l', @log_file, '-f'])
       rescue EOFError => e
         puts @output.string
         raise
       end
       expect( File.exists?( @answers_output_file ) ).to be true
     end

     it 'creates valid answers yaml using existing file, command line overrides, and prompts' do
       skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
       input_string = "\n" # use suggested interface, as has to be a valid one
       @input.reopen(input_string)
       @input.rewind
       begin
         Simp::Cli::Commands::Config.run([
           '-o', @answers_output_file,
           '--apply-with-questions', File.join(files_dir, 'prev_simp_conf.yaml'),
           '-l', @log_file,
           'simp::runlevel=4',
           'simp_options::dns::servers=1.2.3.10,,1.2.3.11,,1.2.3.12'])
       rescue Exception =>e
         puts '=========stdout========='
         puts @output.string
         raise
       end
       expect( File.exists?( @answers_output_file ) ).to be true

       # normalize out lines that are not deterministic
       expected = normalize(File.join(files_dir, 'simp_conf_with_overrides.yaml'))
       actual_simp_conf = normalize(@answers_output_file)
       expect( actual_simp_conf ).to eq expected
     end

     it 'does not apply actions when user is not root' do
       skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
       @input.reopen(generate_simp_input_accepting_defaults)
       begin
         Simp::Cli::Commands::Config.run(['-o', @answers_output_file,
           '-l', @log_file])
       rescue Exception =>e
         puts '=========stdout========='
         puts @output.string
         raise
       end

       # only look at non-FIPS-related skip lines
       # (FIPS mode is detected automatically and can't be assumed to be
       #  on/off for the server running running this test)
       skip_lines = @output.string.split("\n").delete_if do |line|
         !line.include?('Skipping apply[**user is not root**]') or
           line.include?('digest algorithm to work with FIPS')
       end

       fmt_begin = "\e[35m\e[1m"
       fmt_end = "\e[0m"
       skip_msg = '(Skipping apply[**user is not root**])'
       expected_lines = [
         "#{fmt_begin}#{skip_msg}#{fmt_end} Set $simp_scenario in simp environment's site.pp",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Configure a network interface",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Set hostname",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Set GRUB password",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Set default Puppet environment to 'simp'",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Set up Puppet autosign",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Update Puppet settings",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Ensure Puppet server /etc/hosts entry exists",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Create SIMP server <host>.yaml from template",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Set PuppetDB master server & port in SIMP server <host>.yaml",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Enable remote YUM repos in SIMP server <host>.yaml",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Check remote YUM configuration",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Add simp::server::ldap class to SIMP server <host>.yaml",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Set LDAP Sync & Root password hashes in SIMP server <host>.yaml",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Generate interim certificates for SIMP server",
         "#{fmt_begin}#{skip_msg}#{fmt_end} Write SIMP global hieradata to YAML file."
       ]

       if expected_lines.size != skip_lines.size
         puts "Expected:\n"
         expected_lines.each { |line| puts "\t" + line.inspect }
         puts "Actual:\n"
         skip_lines.each { |line| puts "\t" + line.inspect }
       end
       expect(skip_lines.size).to eq expected_lines.size

       skip_lines.each_index do |index|
         expect(skip_lines[index]).to eq expected_lines[index]
       end
     end

     it 'prints a summary of actions' do
       skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
       @input.reopen(generate_simp_input_accepting_defaults)
       begin
         Simp::Cli::Commands::Config.run(['-o', @answers_output_file,
           '-p', @puppet_system_file, '-l', @log_file])
       rescue Exception =>e
         puts '=========stdout========='
         puts @output.string
         raise
       end

       summary_lines = @output.string.split('Summary of Applied Changes')[1].split("\n")
       summary_lines.shift # get rid of rest of Summary line (color formatting)
       summary_lines.delete_if { |line| line.chomp.empty? } # get rid of empty lines

       expected_lines = [
         %r{Setting of \$simp_scenario in the simp environment's site.pp skipped}m,
         %r{Configuration of a network interface skipped}m,
         %r{Setting of hostname skipped}m,
         %r{Setting of GRUB password skipped}m,
         %r{Setting 'simp' to the Puppet default environment skipped}m,
         %r{Setup of autosign in #{@tmp_dir}/autosign.conf skipped}m,
         %r{Update to Puppet settings in #{@tmp_dir}/puppet.conf skipped}m,
         %r{Update to /etc/hosts to ensure puppet server entries exist skipped}m,
         %r{Creation of SIMP server <host>.yaml skipped}m,
         %r{Setting of PuppetDB master server & port in SIMP server <host>.yaml skipped}m,
         %r{Enabling of remote system .OS. and SIMP YUM repositories in SIMP server <host>.yaml}m,
         %r{Checking remote YUM configuration skipped}m,
         %r{Addition of simp::server::ldap to SIMP server <host>.yaml class list skipped}m,
         %r{Setting of LDAP Sync & Root password hashes in SIMP server <host>.yaml skipped}m,
         %r{Interim certificate generation for SIMP server skipped}m,
         %r{Creation of #{@puppet_system_file} skipped}m,
         %r{#{@answers_output_file} created}m,
         %r{Detailed log written to #{@log_file}}m,
       ]
       if expected_lines.size != summary_lines.size
         puts "Expected:\n"
         expected_lines.each { |line| puts "\t" + line.inspect }
         puts "Actual:\n"
         summary_lines.each { |line| puts "\t" + line.inspect }
       end
       expect(summary_lines.size).to eq expected_lines.size
       summary_lines.each_index do |index|
         expect(summary_lines[index]).to match expected_lines[index]
       end
     end
    end

    context 'creates detailed log file' do
       it 'logs detailed messages when normal verbosity specified' do
         skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
         @input.reopen(generate_simp_input_accepting_defaults)
         begin
           Simp::Cli::Commands::Config.run(['-o', @answers_output_file,
             '-p', @puppet_system_file, '-l', @log_file])
         rescue Exception =>e
           puts '=========stdout========='
           puts @output.string
           raise
         end

         expect( File.exists?( @log_file ) ).to be true

         #FIXME validate full file content, not just that it contains debug-level messages
         content = IO.read(@log_file)
         expect( content ).to match /Loading answers from .*\/simp.yaml/
       end

       it 'logs detailed messages when quiet verbosity specified' do
         skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
         @input.reopen(generate_simp_input_accepting_defaults)
         begin
           Simp::Cli::Commands::Config.run(['-o', @answers_output_file,
             '-p', @puppet_system_file, '-l', @log_file, '--quiet'])
         rescue Exception =>e
           puts '=========stdout========='
           puts @output.string
           raise
         end

         expect( File.exists?( @log_file ) ).to be true

         #FIXME validate full file content, not just that it contains debug-level messages
         content = IO.read(@log_file)
         expect( content ).to match /Loading answers from .*\/simp.yaml/
       end
    end

    context 'when -dry-run option selected' do
      it 'creates a answers output yaml file' do
        @input.reopen(generate_simp_input_accepting_defaults)
        begin
          Simp::Cli::Commands::Config.run(['--dry-run', '-o', @answers_output_file,
            '-p', @puppet_system_file, '-l', @log_file])
        rescue Exception =>e
          puts '=========stdout========='
          puts @output.string
          raise
        end

        expect( File.exists?( @answers_output_file ) ).to be true
      end

      it "reports 'dry run' skip reason" do
        @input.reopen(generate_simp_input_accepting_defaults)
        begin
          Simp::Cli::Commands::Config.run(['--dry-run', '-o', @answers_output_file,
            '-p', @puppet_system_file, '-l', @log_file])
        rescue Exception =>e
          puts '=========stdout========='
          puts @output.string
          raise
        end

        correct_skip_regex = Regexp.new(Regexp.escape('(Skipping apply[**dry run**])'))
        incorrect_skip_regex = Regexp.new(Regexp.escape('(Skipping apply[**user is not root**])'))
        expect( @output.string ).to match correct_skip_regex
        expect( @output.string ).not_to match incorrect_skip_regex
      end

      it 'prompts user' do
        @input.reopen(generate_simp_input_accepting_defaults)
        begin
          Simp::Cli::Commands::Config.run(['--dry-run', '-o', @answers_output_file,
            '-p', @puppet_system_file, '-l', @log_file])
        rescue Exception =>e
          puts '=========stdout========='
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
    end

    it 'logs debug output to the console when --verbose option selected' do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
      @input.reopen(generate_simp_input_accepting_defaults)
      begin
        Simp::Cli::Commands::Config.run(['-o', @answers_output_file,
          '-p', @puppet_system_file, '-l', @log_file, '--verbose'])
      rescue Exception =>e
        puts '=========stdout========='
        puts @output.string
        raise
      end

      expect( @output.string ).to match /Loading answers from .*\/simp.yaml/
    end

    it 'logs minimal output to the console when --quiet option selected' do
    end

    context 'when safety-save file exists' do
      it 'reads in file and report last item answered by user'
      it 'applies file when user selects default safety-save option at prompt'
      it "discards file and does not apply when user enters 'no' at prompt"
      it 'automatically applies safety-save file when --accept-safety-save option specified'
      it "automatically discards file and does not apply when --skip-safety-save option specified"
    end

    it 'raises an RuntimeError when noninteractive and input yaml is incomplete' do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'

      expect {  Simp::Cli::Commands::Config.run(['-o', @answers_output_file, '--apply',
        File.join(files_dir, 'prev_simp_conf.yaml'), '-l', @log_file]) }.to raise_error(RuntimeError,
          "FATAL: no answer for 'cli::network::interface'")
    end

    it 'raises an RuntimeError when noninteractive and input answers yaml has an invalid value' do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'

      # Since network::interface value fails validation when read in, that value
      # is skipped. This results in a missing anwer for network::interface.
      expect {  Simp::Cli::Commands::Config.run(['-o', @answers_output_file, '--apply',
        File.join(files_dir, 'bad_simp_conf.yaml'), '-l', @log_file]) }.to raise_error(RuntimeError,
          "FATAL: no answer for 'cli::network::interface'")
    end
  end

  describe '.read_answers_file' do
    before :each do
      @yaml_file = File.join(@tmp_dir, 'answers.yaml')
    end

    after :each do
      FileUtils.chmod 0777, @yaml_file if File.exists?(@yaml_file)
      FileUtils.remove_entry_secure @tmp_dir
    end

    it 'raises exception when file to parse cannot be accessed' do
      expect { Simp::Cli::Commands::Config.read_answers_file('oops.yaml') }.to raise_error(
        RuntimeError, "ERROR: Could not access the file 'oops.yaml'!")
    end

    it 'returns hash when file contains valid yaml' do
      File.open(@yaml_file, 'w') do |file|
        file.puts('network::dhcp: static')
        file.puts('network::hostname: puppet.test.local')
        file.puts('network::ipaddress: "1.2.3.4"')
        file.puts('network::netmask: "255.255.255.0"')
        file.puts('network::gateway: "1.2.3.1"')
        file.puts('"simp_options::dns::servers":')
        file.puts('  - "1.2.3.10"')

      end
      expected = {
        'network::dhcp' => 'static',
        'network::hostname' => 'puppet.test.local',
        'network::ipaddress' => '1.2.3.4',
        'network::netmask' => '255.255.255.0',
        'network::gateway' => '1.2.3.1',
        'simp_options::dns::servers' => ['1.2.3.10']
      }
      expect( Simp::Cli::Commands::Config.read_answers_file(@yaml_file) ).to eq expected
    end

    it 'returns empty hash when file is empty' do
      FileUtils.touch(@yaml_file)
      expected = {}
      expect( Simp::Cli::Commands::Config.read_answers_file(@yaml_file) ).to eq expected
    end

    it 'returns empty hash when file is only comments' do
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

    it 'raises exception when file contains malformed yaml' do
      File.open(@yaml_file, 'w') do |file|
        file.puts('====')
        file.puts('simp_options::fips:')
      end
      expect { Simp::Cli::Commands::Config.read_answers_file(@yaml_file) }.to raise_error(
        RuntimeError, /ERROR: System configuration file '#{@yaml_file}' is corrupted/)
    end
  end
end
