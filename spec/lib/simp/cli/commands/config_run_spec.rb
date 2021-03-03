require 'simp/cli/commands/config'

require_relative 'config_spec_helper'
require 'test_utils/string_io'

require 'fileutils'
require 'set'
require 'spec_helper'
require 'timeout'
require 'yaml'

# NOTE: Simp::Cli::Command::Config#run can hang if bad input is
#       specified and the reprompt logic is outside of the HighLine
#       library. (HighLine raises EOFError when input is exhausted
#       while reading in values.)  So, to help debug input problems
#       that are not caught by HighLine, Simp::Cli::Command::Config#run
#       calls are wrapped in a Timeout block.

describe 'Simp::Cli::Command::Config#run' do
  let(:files_dir) { File.join(__dir__, 'files') }
  let(:max_config_run_seconds) { 60 }

  let(:facts) { {
    'fips_enabled'     => true,
    'fqdn'             => 'server.example.com',
    'is_pe'            => false,
    'ipaddress_enp0s3' => '10.0.2.10',
    'netmask_enp0s3'   => '255.255.255.0',
    'networking'       => {
      'interfaces' => {
        'enp0s3' => { 'ip' => '10.0.2.10' },
        'lo'     => { 'ip' => '127.0.0.1' },
      },
      'ip'        => '10.0.2.10',
      'primary'   => 'enp0s3'
    },
    'os'               => {
      'release' => {
        'major' => '7'
      }
     }
  } }

  before(:each) do
    @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__) )

    allow(Facter).to receive(:loadfacts).and_return(nil)
    facts.keys.each do |fact_name|
      allow(Facter).to receive(:value).with(fact_name).and_return(facts[fact_name])
    end

    # Needed to ensure we execute expected decision tree paths
    iso_repo ='/etc/yum.repos.d/simp_filesystem.repo'
    allow(File).to receive(:exist?).with(any_args).and_call_original
    allow(File).to receive(:exist?).with(iso_repo).and_return(false)

    @input = TestUtils::StringIO.new
    @output = TestUtils::StringIO.new
    HighLine.default_instance = HighLine.new(@input, @output)
    @answers_output_file = File.join(@tmp_dir, 'simp_conf.yaml')
    @puppet_system_file = File.join(@tmp_dir, 'simp_config_settings.yaml')
    @log_file = File.join(@tmp_dir, 'simp_config.log')

    @config = Simp::Cli::Commands::Config.new
  end

  after :each do
    @input.close
    @output.close
    HighLine.default_instance = HighLine.new
    FileUtils.remove_entry_secure @tmp_dir, true
    Facter.reset  # make sure this test's facts don't affect other tests
  end

  # answers/hieradata values derived from facts when a test uses defaults
  let(:keys_from_mocked_facts) { {
    'cli::network::ipaddress' => '10.0.2.10',
    'cli::network::netmask'   => '255.255.255.0',
    'simp_options::trusted_nets' => [ '10.0.2.0/24' ]
  } }

  # answer/hieradata data that can't be mocked during a test using defaults:
  # - password/password hashes generated during the test
  # - default info derived from the actual server on which the unit test is
  #   running (e.g. `hostname -A`)
  let(:extra_keys_to_exclude) { [
      'cli::network::gateway',
      'cli::network::hostname',
      'simp_options::dns::servers',
      'simp_options::dns::search',
      'simp_options::ldap::base_dn',
      'simp_options::ldap::bind_pw',
      'simp_options::ldap::master',
      'simp_options::ldap::sync_pw',
      'simp_options::ldap::uri',
      'simp_options::puppet::ca',
      'simp_options::puppet::server',
   ] }

  context 'creates SIMP global hieradata file when input is valid and user is root' do
    it 'hieradata file contains only hieradata' do
      skip('Tested in acceptance test')
    end
  end

  context 'creates answers YAML file when input is valid' do

    it "creates valid file for 'simp' scenario, interactively accepting all defaults" do

      @input.reopen(generate_simp_input_accepting_defaults)
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
            '-l', @log_file, '--dry-run'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( File.exist?( @answers_output_file ) ).to be true

      # normalize out YAML keys that are not deterministic
      expected = config_normalize(
        File.join(files_dir, 'simp_conf_accepting_defaults_simp_scenario.yaml'),
        extra_keys_to_exclude,
        keys_from_mocked_facts
      )
      actual_simp_conf = config_normalize(@answers_output_file, extra_keys_to_exclude)
      expect( actual_simp_conf ).to eq expected
    end

    it "creates valid file for 'simp_lite' scenario, interactively setting values" do
      @input.reopen(generate_simp_lite_input_setting_values)
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
            '-l', @log_file, '--dry-run'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( File.exist?( @answers_output_file ) ).to be true

      # normalize out YAML keys that are not deterministic
      expected = config_normalize(
        File.join(files_dir, 'simp_conf_setting_values_simp_lite_scenario.yaml')
      )
      actual_simp_conf = config_normalize(@answers_output_file)
      expect( actual_simp_conf ).to eq expected
    end

    it "creates valid file for 'poss' scenario, interactively setting values " do
      @input.reopen(generate_poss_input_setting_values)
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
            '-l', @log_file, '--dry-run'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( File.exist?( @answers_output_file ) ).to be true

      # normalize out YAML keys that are not deterministic
      expected = config_normalize(File.join(files_dir, 'simp_conf_setting_values_poss_scenario.yaml'))
      actual_simp_conf = config_normalize(@answers_output_file)
      expect( actual_simp_conf ).to eq expected
    end

    it 'creates valid file with minimal prompts when --force-defaults' do
      input_string = ''
      input_string <<
                "\n"                         << # accept auto-generated grub password
                "iTXA8O6yC=DMotMGTeHd7IGI\n" << # LDAP root password
                "iTXA8O6yC=DMotMGTeHd7IGI\n" << # confirm LDAP root password
                "P@ssw0rdP@ssw0rd!\n"        << # simpadmin password
                "P@ssw0rdP@ssw0rd!\n"           # confirm simpadmin password
      @input.reopen(input_string)
      @input.rewind

      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
            '-l', @log_file, '--dry-run', '--force-defaults'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( File.exist?( @answers_output_file ) ).to be true
    end

    it 'creates valid file with no prompts when --force-defaults and KEY=VALUE arguments are complete' do
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
          '-l', @log_file, '--dry-run', '--force-defaults',
          'cli::network::interface=enp0s3',
          'simp_openldap::server::conf::rootpw={SSHA}UJEQJzeoFmKAJX57NBNuqerTXndGx/lL',
          'grub::password=grub.pbkdf2.sha512.10000.512AEFAA6DBAB5E70A9C8368B4D7AFAD95CEC1E2203880B738750B8168E0C0BD37C20E6C4186B81B988176DD4A92F292B633893CB0A77C6CBD9799B290325C86.7414615C530889529098000561BC6B2B67415F97F4D387194631324065562F2BD3E2BFE80B29FF9AC2A32AC4BD86036FCBB1CAA0E8B5454DA9DCD2B17124A103',
           'cli::local_priv_user_password=$6$l69r7t36$WZxDVhvdMZeuL0vRvOrSLMKWxxQbuK1j8t0vaEq3BW913hjOJhRNTxqlKzDflPW7ULPwkBa6xdfcca2BlGoq/.'
          ])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( File.exist?( @answers_output_file ) ).to be true
    end

    it 'creates valid file from valid answers file using --apply-with-questions and no prompts' do
      input_answers_file = File.join(files_dir, 'prev_simp_conf.yaml')
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run([
            '-o', @answers_output_file,
            '--apply-with-questions', input_answers_file,
            '-l', @log_file, '--dry-run'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( File.exist?( @answers_output_file ) ).to be true
      # Only change we expect is for hardcoded cli::version to have been updated
      expected = YAML.load(File.read(input_answers_file))
      expected['cli::version'] = Simp::Cli::VERSION

      actual_simp_conf = YAML.load(File.read(@answers_output_file))
      expect( actual_simp_conf ).to eq expected
    end

    it 'creates valid file from incomplete answers file using --apply-with-questions and prompts for only iteractive items' do
      input_string = "enp0s3\n" # interface, only interactive value that is incorrect
      @input.reopen(input_string)
      @input.rewind
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run([
            '-o', @answers_output_file,
            '--apply-with-questions', File.join(files_dir, 'incomplete_prev_simp_conf.yaml'),
            '-l', @log_file, '--dry-run'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( File.exist?( @answers_output_file ) ).to be true
      # we expect
      # - missing, non-interactive puppetdb::master::config::puppetdb_port and
      #   puppetdb::master::config::puppetdb_server to have been added
      # - interactive cli::network::interface to have been replaced with input value
      # - hardcoded cli::version to have been updated
      expected = YAML.load(File.read(File.join(files_dir, 'prev_simp_conf.yaml')))
      expected['cli::version'] = Simp::Cli::VERSION

      actual_simp_conf = YAML.load(File.read(@answers_output_file))
      actual_simp_conf = {} if !actual_simp_conf.is_a?(Hash) # empty YAML file returns false

      expect( actual_simp_conf ).to eq expected
    end

    it 'creates valid file answers file using --apply-with-questions, KEY=VALUE and prompts for invalid items' do
      input_string = "enp0s3\n"
      @input.reopen(input_string)
      @input.rewind
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run([
            '-o', @answers_output_file,
            '--apply-with-questions', File.join(files_dir, 'prev_simp_conf_invalid_interface.yaml'),
            '-l', @log_file, '--dry-run',
            'simp::runlevel=4',
            'simp_options::dns::servers=1.2.3.10,,1.2.3.11,,1.2.3.12'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( File.exist?( @answers_output_file ) ).to be true

      # normalize out lines that are not deterministic
      expected = config_normalize(File.join(files_dir, 'simp_conf_with_overrides.yaml'))
      actual_simp_conf = config_normalize(@answers_output_file)
      expect( actual_simp_conf ).to eq expected
    end

    it 'creates valid file from valid answers file using --apply' do
      input_answers_file = File.join(files_dir, 'prev_simp_conf.yaml')
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run([
            '-o', @answers_output_file,
            '--apply', input_answers_file,
            '-l', @log_file, '--dry-run'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( File.exist?( @answers_output_file ) ).to be true
      expected = YAML.load(File.read(input_answers_file))
      expected['cli::version'] = Simp::Cli::VERSION

      actual_simp_conf = YAML.load(File.read(@answers_output_file))
      expect( actual_simp_conf ).to eq expected
    end

    it 'creates valid file using --apply and KEY=VALUE arguments' do
      input_answers_file = File.join(files_dir, 'prev_simp_conf_invalid_interface.yaml')
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run([
            '-o', @answers_output_file,
            '--apply', input_answers_file,
            '-l', @log_file, '--dry-run',
            'cli::network::interface=enp0s3'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( File.exist?( @answers_output_file ) ).to be true

      expected = YAML.load(File.read((File.join(files_dir, 'prev_simp_conf.yaml'))))
      expected['cli::version'] = Simp::Cli::VERSION

      actual_simp_conf = YAML.load(File.read(@answers_output_file))
      actual_simp_conf = {} if !actual_simp_conf.is_a?(Hash) # empty YAML file returns false

      expect( actual_simp_conf ).to eq expected
    end
  end

  context 'applies actions appropriately' do

    it 'when user is root, applies all actions' do
      skip('Tested in acceptance test')
    end

    it 'when user is not root, fails if --dry-run is not selected' do
      not_safe_msg  = "To prevent inadvertent system changes, this test will not be run when 'root' user"
      skip(not_safe_msg) if ENV['USER'] == 'root' or ENV['HOME'] == '/root'

      expect {
        @config.run(['-o', @answers_output_file, '-l', @log_file])
      }.to raise_error( Simp::Cli::ProcessingError,
       /Non\-root users must use \-\-dry\-run option/)
    end
  end

  context 'reports results to the console' do

    it 'prints a summary of actions' do
      @input.reopen(generate_simp_input_accepting_defaults)
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
            '-p', @puppet_system_file, '-l', @log_file, '--dry-run'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end

      summary_lines = @output.string.split('Summary of Applied Changes')[1].split("\n")
      summary_lines.shift # get rid of rest of Summary line (color formatting)
      summary_lines.delete_if { |line| line.chomp.empty? } # get rid of empty lines

      expected_lines = [
        %r{Setting of hostname skipped}m,
        %r{Configuration of a network interface skipped}m,
        %r{Setting of GRUB password skipped}m,
        %r{Creation of local user skipped}m,
        %r{Setup of autosign in /etc/puppetlabs/puppet/autosign.conf skipped}m,
        %r{Update to Puppet settings in /etc/puppetlabs/puppet/puppet.conf skipped}m,
        %r{Update to /etc/hosts to ensure puppet server entries exist skipped}m,
        %r{Setting of \$simp_scenario in the simp environment's site.pp skipped}m,
        %r{Interim certificate generation for SIMP server skipped}m,
        %r{Creation of #{@puppet_system_file} skipped}m,
        %r{Creation of SIMP server <host>.yaml skipped}m,
        %r{Setting of PuppetDB master server & port in SIMP server <host>.yaml skipped}m,
        %r{Addition of simp::server::ldap to SIMP server <host>.yaml class list skipped}m,
        %r{Setting of LDAP Root password hash in SIMP server <host>.yaml skipped}m,
        %r{Disable of inapplicable user config in SIMP server <host>.yaml skipped}m,
        %r{Configuring ssh & sudo for local user 'simpadmin' in SIMP server <host>.yaml skipped}m,
        %r{'simpadmin' access verification after `simp bootstrap` skipped}m,
        %r{#{@answers_output_file} created}m,
        %r{Detailed log written to #{@log_file}}m
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

    it 'logs info-level output to the console when --verbose option selected' do
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
            '--apply-with-questions', File.join(files_dir, 'prev_simp_conf.yaml'),
            '-l', @log_file, '--dry-run', '--verbose'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end

      expect( @output.string ).to match /Loading answers from .*\/prev_simp_conf.yaml/
    end

    it 'logs no non-error output to the console when --quiet option selected' do
      @input.reopen(generate_simp_input_accepting_defaults(false))
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
          '--force-defaults', '-l', @log_file, '--dry-run',
          '--disable-queries',
          'simp_openldap::server::conf::rootpw={SSHA}UJEQJzeoFmKAJX57NBNuqerTXndGx/lL',
          'grub::password=grub.pbkdf2.sha512.10000.512AEFAA6DBAB5E70A9C8368B4D7AFAD95CEC1E2203880B738750B8168E0C0BD37C20E6C4186B81B988176DD4A92F292B633893CB0A77C6CBD9799B290325C86.7414615C530889529098000561BC6B2B67415F97F4D387194631324065562F2BD3E2BFE80B29FF9AC2A32AC4BD86036FCBB1CAA0E8B5454DA9DCD2B17124A103',
           'cli::local_priv_user_password=$6$l69r7t36$WZxDVhvdMZeuL0vRvOrSLMKWxxQbuK1j8t0vaEq3BW913hjOJhRNTxqlKzDflPW7ULPwkBa6xdfcca2BlGoq/.',
          '--quiet'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end

      expect( @output.string.empty? ).to be true
    end
  end

  context 'creates detailed log file' do
    it 'logs detailed messages when normal verbosity specified' do
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
            '--apply-with-questions', File.join(files_dir, 'prev_simp_conf.yaml'),
            '-l', @log_file, '--dry-run'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end

      expect( File.exist?( @log_file ) ).to be true

      #FIXME validate full file content, not just that it contains debug-level messages
       content = IO.read(@log_file)
       expect( content ).to match /Loading answers from .*\/prev_simp_conf.yaml/
    end

    it 'logs detailed messages when quiet verbosity specified' do
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
            '--apply-with-questions', File.join(files_dir, 'prev_simp_conf.yaml'),
            '-p', @puppet_system_file, '-l', @log_file, '--dry-run',
            '--quiet'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end

      expect( File.exist?( @log_file ) ).to be true

      #FIXME validate full file content, not just that it contains debug-level messages
      content = IO.read(@log_file)
      expect( content ).to match /Loading answers from .*\/prev_simp_conf.yaml/
    end
  end

  context 'when -dry-run option selected' do

    # only dry run capability not verified by other tests is the skip reason
    it "reports 'dry run' skip reason" do
      @input.reopen(generate_simp_input_accepting_defaults)
      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['--dry-run', '-o', @answers_output_file,
            '-p', @puppet_system_file, '-l', @log_file])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end

      correct_skip_regex = Regexp.new(Regexp.escape('(Skipping apply[**dry run**])'))
      incorrect_skip_regex = Regexp.new(Regexp.escape('(Skipping apply[**user is not root**])'))
      expect( @output.string ).to match correct_skip_regex
      expect( @output.string ).not_to match incorrect_skip_regex
    end
  end

  context 'when safety-save file exists' do
    it 'reads in file and report last item answered by user'
    it 'applies file when user selects default safety-save option at prompt'
    it "discards file and does not apply when user enters 'no' at prompt"
    it 'automatically applies safety-save file when --accept-safety-save option specified'
    it 'automatically discards file and does not apply when --skip-safety-save option specified'
  end

  context 'when invalid passwords are input' do
    it 'starts over when user enters different inputs for a password' do
      input_string = ''
      input_string <<
                "\n"                         << # accept auto-generated grub password
                "iTXA8O6y{oDMotMGTeHd7IGI\n" << # attempt 1: LDAP root password
                "iTXA8O6y{oDMotMGTeHd7\n"    << # attempt 1: bad confirm password
                "iTXA8O6y{oDMotMGTeHd7IGI\n" << # attempt 2: LDAP root password
                "iTXA8O6y{oDMotMGTeHd7IGI\n" << # attempt 2: valid confirm LDAP root password
                "P@ssw0rdP@ssw0rd!\n"        << # attempt 1: simpadmin password
                "P@ssw0rdP@ssw\n"            << # attempt 1: bad confirm password
                "P@ssw0rdP@ssw0rd!\n"        << # attempt 2: simpadmin password
                "P@ssw0rdP@ssw0rd!\n"           # attempt 2: valid confirm simpadmin password
      @input.reopen(input_string)
      @input.rewind

      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
            '-l', @log_file, '--dry-run', '--force-defaults'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end
      expect( @output.string ).to match /WARNING: Passwords did not match!  Please try again/

      pw_prompt_lines = @output.string.split("\n").delete_if do |line|
        !line.include?('Please enter a password') and
        !line.include?('Please confirm the password')
      end
      expect( pw_prompt_lines.size ).to eq 8

      expect( File.exist?( @answers_output_file ) ).to be true
    end

    it 'fails after 5 failed start-over attempts' do
      input_string = "\n"    # accept auto-generated grub password
      (1..5).each do |attempt|
        input_string << "iTXA8O6y{oDMotMGTeHd7IGI\n"          # valid LDAP root password
        input_string << "Bad confirm password #{attempt}\n"   # non-matching confirm
       end
      @input.reopen(input_string)
      @input.rewind

      expect {
        @config.run(['-o', @answers_output_file,
          '-l', @log_file, '--dry-run', '--force-defaults'])
      }.to raise_error( Simp::Cli::ProcessingError,
       /FATAL: Too many failed attempts to enter password/)
    end

    it 're-prompts when user enters a password that fails validation' do
      input_string = ''
      input_string <<
                "\n"                         << # accept auto-generated grub password
                "}.9rt\n"                    << # attempt 1: too short + needs brace escape
                "1234567890{\n"              << # attempt 2: fails cracklib check + needs brace escape
                "iTXA8O6y}.9MotMGTeHd7IGI\n" << # attempt 3: good LDAP root password
                "iTXA8O6y}.9MotMGTeHd7IGI\n" << # attempt 3: valid confirm LDAP root password
                "P@ssw0rdP@ssw0rd!\n"        << # attempt 1: simpadmin password
                "P@ssw0rdP@ssw0rd!\n"           # attempt 1: valid confirm simpadmin password
      @input.reopen(input_string)
      @input.rewind

      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run(['-o', @answers_output_file,
            '-l', @log_file, '--dry-run', '--force-defaults'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end

      expect( @output.string ).to match /Invalid Password:/
      error_lines = @output.string.split("\n").delete_if do |line|
        !line.include?('Invalid Password:')
      end

      expect( error_lines.size ).to eq 2
      expect( File.exist?( @answers_output_file ) ).to be true
    end

    it 'prompts when --apply-with-questions and input file has an invalid password' do
      bad_password = 'Un=3nCryPte6'  # should be encrypted in answers file
      input = File.read(File.join(files_dir, 'prev_simp_conf.yaml'))
      input.gsub!(/oops_force_replacement/, 'enp0s3')
      input.gsub!(/simp_openldap::server::conf::rootpw: .*\n/,
         "simp_openldap::server::conf::rootpw: \"#{bad_password}\"\n")
      input_answers_file = File.join(@tmp_dir, 'prev_simp_conf.yaml')
      File.open(input_answers_file,'w') { |file| file.puts(input) }

      input_string = ''
      input_string <<
                "\n"                         << # don't auto-generate LDAP root password
                "iTXA8O6y}.9MotMGTeHd7IGI\n" << # replacement LDAP root password
                "iTXA8O6y}.9MotMGTeHd7IGI\n"    # confirm replacement LDAP root password
      @input.reopen(input_string)
      @input.rewind

      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run([
            '-o', @answers_output_file,
            '--apply-with-questions', input_answers_file,
            '-l', @log_file, '--dry-run'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end

      warn_msg = "invalid value '#{bad_password}' for 'simp_openldap::server::conf::rootpw' will be **IGNORED**"
      expect( @output.string ).to match Regexp.escape(warn_msg)
      expect( File.exist?( @answers_output_file ) ).to be true

      actual_simp_conf = YAML.load(File.read(@answers_output_file))
      expect( actual_simp_conf ).to_not match bad_password
    end

    it 'prompts for new password hash when --apply-with-questions and input file has a password that does not match its hash' do
      # valid password that does not match its encrypted value
      different_pw = 'Puy.c&48I1A8#PI1JW#&gX*4ugn!whg7'
      input = File.read(File.join(files_dir, 'prev_simp_conf.yaml'))
      input.gsub!(/oops_force_replacement/, 'enp0s3')
      input.gsub!(/simp_options::ldap::bind_pw: .*\n/,
         "simp_options::ldap::bind_pw: \"#{different_pw}\"\n")
      input_answers_file = File.join(@tmp_dir, 'prev_simp_conf.yaml')
      File.open(input_answers_file,'w') { |file| file.puts(input) }

      input_string = "\n" # accept recommended replacement password hash
      @input.reopen(input_string)
      @input.rewind

      begin
        Timeout.timeout(max_config_run_seconds) do
          @config.run([
            '-o', @answers_output_file,
            '--apply-with-questions', input_answers_file,
            '-l', @log_file, '--dry-run'])
        end
      rescue Exception => e # generic to capture Timeout and misc HighLine exceptions
        puts '=========stdout========='
        puts @output.string
        raise
      end

      warn_msg = "'simp_options::ldap::bind_hash' will be **IGNORED**"
      expect( @output.string ).to match Regexp.escape(warn_msg)

      match = @output.string.match(/recommended value: "({SSHA}.*)"/)
      expect( match ).to_not be_nil
      expect( File.exist?( @answers_output_file ) ).to be true

      actual_simp_conf = YAML.load(File.read(@answers_output_file))
      expect( actual_simp_conf['simp_options::ldap::bind_hash'] ).to eq match[1]
    end
  end

  context 'when valid input cannot be gathered' do

    it 'raises an exception when --apply and input YAML is missing cli::simp::scenario' do
      # this exercises an error path in config.rb, not item.rb
      expect {
        @config.run(['-o', @answers_output_file,
        '--apply', File.join(files_dir, 'simp_conf_missing_scenario.yaml'),
        '-l', @log_file, '--dry-run'])
      }.to raise_error( Simp::Cli::ProcessingError,
       "FATAL: No valid answer found for 'cli::simp::scenario'")
    end

    it 'raises an exception when --apply and input YAML is incomplete' do
      expect {
        @config.run(['-o', @answers_output_file,
        '--apply', File.join(files_dir, 'incomplete_prev_simp_conf.yaml'),
        '-l', @log_file, '--dry-run'])
      }.to raise_error( Simp::Cli::ProcessingError,
       "FATAL: No answer found for 'cli::network::interface'")
    end

    it 'raises an exception when --apply and input YAML has an invalid value' do
      # prev_simp_conf.yaml has a bad interface value that must be 
      # fixed via prompt or override
      expect {
        @config.run(['-o', @answers_output_file,
          '--apply', File.join(files_dir, 'prev_simp_conf_invalid_interface.yaml'),
          '-l', @log_file, '--dry-run'])
      }.to raise_error( Simp::Cli::ProcessingError,
          "FATAL: 'oops_force_replacement' is not a valid answer for 'cli::network::interface'")
    end

    it 'raises an exception when --apply and input YAML has an invalid noninteractive value' do
      input = File.read(File.join(files_dir, 'prev_simp_conf.yaml'))
      input.gsub!('puppetdb::master::config::puppetdb_port: 8139',
        'puppetdb::master::config::puppetdb_port: 0')
      input_answers_file = File.join(@tmp_dir, 'prev_simp_conf.yaml')
      File.open(input_answers_file,'w') { |file| file.puts(input) }
      expect {
        @config.run(['-o', @answers_output_file,
          '--apply', input_answers_file, '-l', @log_file, '--dry-run'])
      }.to raise_error( Simp::Cli::ProcessingError,
          "FATAL: '0' is not a valid answer for 'puppetdb::master::config::puppetdb_port'")
    end


    it 'raises an exception when --disable-queries and input is incomplete' do
      expect {
        # Not all answers can be determined by --force-defaults
        @config.run(['-o', @answers_output_file,
          '--force-defaults', '-l', @log_file, '--dry-run',
          '--disable-queries'])
      }.to raise_error( Simp::Cli::ProcessingError,
       "FATAL: No valid answer found for 'grub::password'")
    end

    it 'raises an exception when --disable-queries and input KEY=VALUE has an invalid value' do
      expect {
        @config.run(['-o', @answers_output_file,
          '--force-defaults', '-l', @log_file, '--dry-run',
          '--disable-queries', 'grub::password=not_encrypted'])
      }.to raise_error( Simp::Cli::ProcessingError,
       "FATAL: No valid answer found for 'grub::password'")
    end

    it 'raises an exception when --disable-queries and input KEY=VALUE has an invalid noninteractive value' do
      expect {
        @config.run(['-o', @answers_output_file,
          '-l', @log_file, '--dry-run',
          '--disable-queries',
          'cli::simp::scenario=simp_lite',
          'cli::network::interface=enp0s3',
          'cli::network::set_up_nic=false',
          'cli::network::hostname=simp.test.local',
          'cli::network::ipaddress=1.2.3.1',
          'cli::network::netmask=255.255.255.0',
          'cli::network::gateway=1.2.3.1',
          'simp_options::dns::servers=1.2.3.10',
          'simp_options::dns::search=test.local',
          'simp_options::trusted_nets=1.2.3.0/24',
          'simp_options::ntp::servers=time-a.nist.gov',
          'cli::set_grub_password=false',
          'puppetdb::master::config::puppetdb_port=0'])

      }.to raise_error( Simp::Cli::ProcessingError,
          "FATAL: '0' is not a valid answer for 'puppetdb::master::config::puppetdb_port'")
    end
  end
end
