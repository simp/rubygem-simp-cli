require 'spec_helper'
require 'simp/cli'


describe 'Simp::Cli' do

  before :all do
    @success_status = 0
    @failure_status = 1
    @result = nil
  end

  before(:each) do
    files_dir = File.join(__dir__, 'cli', 'commands', 'files')
    @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__) )
    test_env_dir = File.join(@tmp_dir, 'environments')
    simp_env_dir = File.join(test_env_dir, 'simp')
    FileUtils.mkdir(test_env_dir)
    FileUtils.cp_r(File.join(files_dir, 'environments', 'simp'), test_env_dir)

    allow(Simp::Cli::Utils).to receive(:puppet_info).and_return( {
      :config => {
        'codedir' => @tmp_dir,
        'confdir' => @tmp_dir
      },
      :environment_path => test_env_dir,
      :simp_environment_path => simp_env_dir,
      :fake_ca_path => File.join(test_env_dir, 'simp', 'FakeCA')
    } )

    allow(Simp::Cli::Utils).to receive(:simp_env_datadir).and_return( File.join(simp_env_dir, 'data') )
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe 'Simp::Cli.start' do
    describe 'help' do
      before :all do
        @usage = "Usage: simp [command]\n" +
                 "\n" +
                 "  Commands\n" +
                 "    - bootstrap\n" +
                 "    - config\n" +
                 "    - doc\n" +
                 "    - passgen\n" +
                 "    - puppetfile\n" +
                 "    - version\n" +
                 "    - help [command]\n\n"
      end

      it 'outputs general usage when no command specified' do
        expect{ @result = Simp::Cli.start([]) }.to output(@usage).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs general usage when help command specified' do
        expect{ @result = Simp::Cli.start(['help']) }.to output(@usage).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs general usage when invalid command specified' do
        expect{ @result = Simp::Cli.start(['oops']) }.to output(/oops is not a recognized command/).to_stderr
        expect( @result ).to be @failure_status
      end

      it 'outputs bootstrap usage when bootstrap help specified' do
        expect{ @result = Simp::Cli.start(['help','bootstrap']) }.to output(/=== The SIMP Bootstrap Tool ===/m).to_stdout
        expect( @result ).to be @success_status
        expect{ @result = Simp::Cli.start(['bootstrap', '-h']) }.to output(/=== The SIMP Bootstrap Tool ===/m).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs config usage when config help specified' do
        expect{ @result = Simp::Cli.start(['help','config']) }.to output(/=== The SIMP Configuration Tool ===/m).to_stdout
        expect( @result ).to be @success_status
        expect{ @result = Simp::Cli.start(['config', '-h']) }.to output(/=== The SIMP Configuration Tool ===/m).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs doc usage when doc help specified' do
        expect{ @result = Simp::Cli.start(['help','doc']) }.to output(/=== The SIMP Doc Tool ===/m).to_stdout
        expect( @result ).to be @success_status
      end

      it 'outputs passgen usage when passgen help specified' do
        expect{ @result = Simp::Cli.start(['help','passgen']) }.to output(/=== The SIMP Passgen Tool ===/m).to_stdout
        expect( @result ).to be @success_status
        expect{ @result = Simp::Cli.start(['passgen', '-h']) }.to output(/=== The SIMP Passgen Tool ===/m).to_stdout
        expect( @result ).to be @success_status
      end
    end

    describe 'fails when invalid command option specified' do
      it 'fails to run bootstrap' do
        expect{ @result = Simp::Cli.start(['bootstrap', '--oops-bootstrap']) }.to output(
          /'bootstrap' command options error: invalid option: --oops-bootstrap/).to_stderr

        expect( @result ).to be @failure_status
      end

      it 'fails to run config' do
        expect{ @result = Simp::Cli.start(['config', '--oops-config']) }.to output(
          /'config' command options error: invalid option: --oops-config/).to_stderr

        expect( @result ).to be @failure_status
      end

      it 'fails to run passgen' do
        expect{ @result = Simp::Cli.start(['passgen', '--oops-passgen']) }.to output(
          /'passgen' command options error: invalid option: --oops-passgen/).to_stderr

        expect( @result ).to be @failure_status
      end

    end
  end
end

