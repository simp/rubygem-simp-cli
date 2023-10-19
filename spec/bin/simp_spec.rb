require 'spec_helper'
require 'timeout'
require 'tmpdir'
require 'rbconfig'

def execute(command, input_file = nil)
  log_tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
  stdout_file = File.join(log_tmp_dir,'stdout.txt')
  stderr_file = File.join(log_tmp_dir,'stderr.txt')
  if input_file
    spawn_args = [:out => stdout_file, :err => stderr_file, :in => input_file]
  else
    spawn_args = [:out => stdout_file, :err => stderr_file]
  end
  pid = spawn(ENV.to_h, command, *spawn_args)

  # in case we have screwed up our test
  Timeout::timeout(30) { Process.wait(pid) }
  exitstatus = $?.nil? ? nil : $?.exitstatus
  stdout = IO.read(stdout_file) if File.exist?(stdout_file)
  stderr = IO.read(stderr_file) if File.exist?(stderr_file)
  { :exitstatus => exitstatus, :stdout => stdout, :stderr => stderr }
ensure
  FileUtils.remove_entry_secure(log_tmp_dir) if log_tmp_dir
end

def execute_and_signal(command, signal_type)
  log_tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
  stdout_file = File.join(log_tmp_dir,'stdout.txt')
  stderr_file = File.join(log_tmp_dir,'stderr.txt')
  pipe_r, pipe_w = IO.pipe
  pid = spawn(ENV.to_h, command, :out => stdout_file, :err => stderr_file, :in => pipe_r)
  pipe_r.close

  # Wait for bytes on stdout.txt, as this tells us the spawned process
  # is up
  Timeout::timeout(30) {
    while File.size(stdout_file) == 0
      sleep 0.5
    end
  }

  Process.kill(signal_type, pid)
  Timeout::timeout(10) { Process.wait(pid) }
  exitstatus = $?.nil? ? nil : $?.exitstatus
  stdout = IO.read(stdout_file) if File.exist?(stdout_file)
  stderr = IO.read(stderr_file) if File.exist?(stderr_file)
  pipe_w.close
  { :exitstatus => exitstatus, :stdout => stdout, :stderr => stderr }
ensure
  FileUtils.remove_entry_secure(log_tmp_dir) if log_tmp_dir
end

# Since most of the functionality will be tested in unit tests,
# this suite is simply to test that class executed within simp
# is hooked in properly:
# - accepts command line arguments
# - returns processing status
# - reads from stdin appropriately
# - handles stdin termination signals appropriately
# - outputs to stdout and stderr appropriately
describe 'simp executable' do
  let(:simp_exe) { File.expand_path('../../bin/simp', __dir__) }

  before :each do

    # Before each test, make sure that the current ruby interpreter will be
    # used when `bin/simp` is executed.  This prevents environmental pollution
    # when running tests on a system with AIO puppet installed.
    adjusted_path = File.join(RbConfig::CONFIG['bindir']) + ':' + ENV['PATH']
    env_hash = ENV.to_h
    env_hash['PATH'] = adjusted_path
    env_hash['USE_AIO_PUPPET'] = 'no'
    allow(ENV).to receive(:[]).with(any_args).and_call_original
    allow(ENV).to receive(:[]).with('PATH').and_return(adjusted_path)
    allow(ENV).to receive(:[]).with('USE_AIO_PUPPET').and_return('no')
    allow(ENV).to receive(:to_h).and_return(env_hash)

    @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
    @simp_config_args = [
      '--dry-run',  # do NOT inadvertently make any changes on the test system
      '-o', File.join(@tmp_dir, 'simp_conf.yaml'),
      '-l', File.join(@tmp_dir, 'simp_config.log')
      ].join(' ')
  end

  after :each do
    FileUtils.remove_entry_secure(@tmp_dir) if @tmp_dir
  end

  context 'when run' do
    it 'handles lack of command line arguments' do
      results = execute(simp_exe)
      warn("=== stderr: #{results[:stderr]}") unless (results[:stderr]).empty?
      warn("=== stdout: #{results[:stdout]}") unless (results[:stdout]).empty?
      expect(results[:exitstatus]).to eq 0
      expect(results[:stdout]).to match(/SIMP Command Line Interface/)
      expect(results[:stderr]).to be_empty
    end

    it 'handles command line arguments' do
      results = execute("#{simp_exe} config -h")
      expect(results[:exitstatus]).to eq 0
      expect(results[:stdout]).to match(/=== The SIMP Configuration Tool ===/)
      expect(results[:stderr]).to be_empty
    end

=begin
FIXME
This test now requires the modern 'networking' fact, which is not
available with Facter 2.x, an old version required by simp-rake-helpers.
Re-enable when this gets worked out.
    it 'processes console input' do
      stdin_file = File.expand_path('files/simp_config_full_stdin_file', __dir__)
      results = execute("#{simp_exe} config #{@simp_config_args}", stdin_file)
      if results[:exitstatus] != 0
        puts '=============stdout===================='
        puts results[:stdout]
        puts '=============stderr===================='
        puts results[:stderr]
      end
      expect(results[:exitstatus]).to eq 0
      expect(results[:stdout].size).not_to eq 0
      #TODO better validation?
      #FIXME  stderr is full of the following messages
      #   "stty: 'standard input': Inappropriate ioctl for device"
      #   From pipes within exec'd code?
    end
=end

    it 'gracefully handles console input termination' do
      stdin_file = File.expand_path('files/simp_config_trunc_stdin_file', __dir__)
      results = execute("#{simp_exe} config #{@simp_config_args}", stdin_file)
      expect(results[:exitstatus]).to eq 1
      expect(results[:stderr]).to match(/Input terminated! Exiting/)
    end

    it 'gracefully handles program interrupt' do
      command = "#{simp_exe} config #{@simp_config_args}"
      results = execute_and_signal(command, 'INT')
      # WORKAROUND
      # When we are running this test on a system in which
      # /opt/puppetlabs/puppet/lib/ruby exists and our environment
      # points to a different ruby (e.g., rvm), multiple rubies will
      # be in the Ruby load path due to kludgey logic in bin/simp.
      # This causes problems. For this test, the SIGINT is not delivered
      # to cli.rb.  The program exits with a status of uncaught SIGINT and
      # a nil exit status.
      unless results[:exitstatus].nil?
        expect(results[:exitstatus]).to eq 1
        expect(results[:stderr]).to match(/Processing interrupted! Exiting/)
      end
    end

    it 'handles other program-terminating signals' do
      command = "#{simp_exe} config #{@simp_config_args}"
      results = execute_and_signal(command, 'HUP')
      expect(results[:exitstatus]).to eq 1
      expect(results[:stderr]).to match(/Process received signal SIGHUP. Exiting/)
    end

    it 'reports processing failures' do
      results = execute("#{simp_exe} bootstrap --oops")
      expect(results[:exitstatus]).to eq 1
      expect(results[:stdout]).to be_empty
      expect(results[:stderr]).to match(
        /'bootstrap' command options error: invalid option: --oops/)
    end
  end
end
