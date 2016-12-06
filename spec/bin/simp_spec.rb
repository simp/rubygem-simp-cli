require 'spec_helper'
require 'timeout'

def execute(command, input_file = nil)
  log_tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
  stdout_file = File.join(log_tmp_dir,'stdout.txt')
  stderr_file = File.join(log_tmp_dir,'stderr.txt')
  if input_file
    spawn_args = [:out => stdout_file, :err => stderr_file, :in => input_file]
  else
    spawn_args = [:out => stdout_file, :err => stderr_file]
  end
  pid = spawn(command, *spawn_args)

  # in case we have screwed up our test
  Timeout::timeout(30) { Process.wait(pid) }
  exitstatus = $?.nil? ? nil : $?.exitstatus
  stdout = IO.read(stdout_file) if File.exists?(stdout_file)
  stderr = IO.read(stderr_file) if File.exists?(stderr_file)
  { :exitstatus => exitstatus, :stdout => stdout, :stderr => stderr }
ensure
  FileUtils.remove_entry_secure(log_tmp_dir) if log_tmp_dir
end

def execute_and_signal(command, signal_type)
  log_tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
  stdout_file = File.join(log_tmp_dir,'stdout.txt')
  stderr_file = File.join(log_tmp_dir,'stderr.txt')
  pipe_r, pipe_w = IO.pipe
  pid = spawn(command, :out => stdout_file, :err => stderr_file, :in => pipe_r)
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
  stdout = IO.read(stdout_file) if File.exists?(stdout_file)
  stderr = IO.read(stderr_file) if File.exists?(stderr_file)
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
describe "simp executable" do
  let(:simp_exe) { File.join(File.dirname(__FILE__), '..', '..', 'bin','simp') }

  before :all do
    env_files_dir = File.join(File.dirname(__FILE__), '..', 'lib', 'simp',
      'cli', 'commands', 'files')
    code_dir = File.join(ENV['HOME'], '.puppetlabs', 'etc', 'code')
    FileUtils.mkdir_p(code_dir)

# FIXME without :verbose option, copy doesn't copy all....
#    FileUtils.cp_r(File.join(env_files_dir, 'environments'), code_dir)
    FileUtils.cp_r(File.join(env_files_dir, 'environments'), code_dir, :verbose => true)
  end

  before :each do
    @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
    @simp_config_args = 
      "-o #{File.join(@tmp_dir, 'simp_conf.yaml')}" +
      "-p #{File.join(@tmp_dir, 'simp_config_settings.yaml')}" +
      "-l #{File.join(@tmp_dir, 'simp_config.log')}"
  end

  after :each do
    FileUtils.remove_entry_secure(@tmp_dir) if @tmp_dir
  end

  context "when run" do
    it "handles lack of command line arguments" do
      results = execute(simp_exe)
      expect(results[:exitstatus]).to eq 0
      expect(results[:stdout]).to match(/Usage: simp \[command\]/)
      expect(results[:stderr]).to be_empty
    end

    it "handles command line arguments" do
      results = execute("#{simp_exe} config -h")
      expect(results[:exitstatus]).to eq 0
      expect(results[:stdout]).to match(/=== The SIMP Configuration Tool ===/)
      expect(results[:stderr]).to be_empty
    end

    it "processes console input" do
      stdin_file = File.join(File.dirname(__FILE__), 'files', 'simp_config_full_stdin_file')
      results = execute("#{simp_exe} config #{@simp_config_args}", stdin_file)
      if results[:exitstatus] != 0
        puts "=============stdout===================="
        puts results[:stdout]
        puts "=============stderr===================="
        puts results[:stderr]
      end
      expect(results[:exitstatus]).to eq 0
      expect(results[:stdout].size).not_to eq 0
      #TODO better validation?
      #FIXME  stderr is full of the following messages
      #   "stty: 'standard input': Inappropriate ioctl for device"
      #   From pipes within exec'd code?
    end

    it "gracefully handles console input termination" do
      stdin_file = File.join(File.dirname(__FILE__), 'files', 'simp_config_trunc_stdin_file')
      results = execute("#{simp_exe} config #{@simp_config_args}", stdin_file)
      expect(results[:exitstatus]).to eq 1
      expect(results[:stderr]).to match(/Input terminated! Exiting/)
    end

    it "gracefully handles program interrupt" do
      command = "#{simp_exe} config #{@simp_config_args}"
      results = execute_and_signal(command, 'INT')
      expect(results[:exitstatus]).to eq 1
      expect(results[:stderr]).to match(/Processing interrupted! Exiting/)
    end

    it "handles other program-terminating signals" do
      command = "#{simp_exe} config #{@simp_config_args}"
      results = execute_and_signal(command, 'HUP')
      expect(results[:exitstatus]).to eq 1
      expect(results[:stderr]).to match(/Process received signal SIGHUP. Exiting/)
    end

    it "reports processing failures" do
      results = execute("#{simp_exe} bootstrap --oops")
      expect(results[:exitstatus]).to eq 1
      expect(results[:stdout]).to be_empty
      expect(results[:stderr]).to match(
        /'bootstrap' command options error: invalid option: --oops/)
    end
  end
end
