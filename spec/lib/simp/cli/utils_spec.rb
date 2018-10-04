require 'simp/cli/utils'
require 'rspec/its'
require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Utils do

  describe '.simp_env_datadir' do
    it 'fails when the simp env datadir cannot be found' do
      allow(Simp::Cli::Utils).to receive(:get_stock_simp_env_datadir).and_return(nil)
      expect{ Simp::Cli::Utils.simp_env_datadir }.to raise_error( Simp::Cli::ProcessingError )
    end

    it 'returns simp env datadir when it can be found' do
      allow(Simp::Cli::Utils).to receive(:get_stock_simp_env_datadir).and_return('/some/dir')
      expect( Simp::Cli::Utils::simp_env_datadir ).to eq '/some/dir'
    end
  end

  describe '.get_stock_simp_env_datadir' do
    let(:files_dir) { File.join(File.dirname(__FILE__), 'commands', 'files') }
    before(:each) do
      @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__) )
      @test_env_dir = File.join(@tmp_dir, 'environments')
      @simp_env_dir = File.join(@test_env_dir, 'simp')
      FileUtils.mkdir_p(@simp_env_dir)

      allow(Simp::Cli::Utils).to receive(:puppet_info).and_return( {
        :config => {
          'codedir' => @tmp_dir,
          'confdir' => @tmp_dir
        },
        :environment_path => @test_env_dir,
        :simp_environment_path => @simp_env_dir,
        :fake_ca_path => File.join(@test_env_dir, 'simp', 'FakeCA')
      } )

    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end

    it 'returns Hiera 5 environment data dir when simp env is configured for Hiera 5' do
      FileUtils.cp_r(File.join(files_dir, 'environments', 'simp'), @test_env_dir)
      expect( Simp::Cli::Utils::get_stock_simp_env_datadir ).to eq File.join(@simp_env_dir, 'data')
    end

    it 'returns Hiera 3 environment data dir when simp env is configured for Hiera 3' do
      FileUtils.cp_r(File.join(files_dir, 'environments', 'simp_hiera3'), @test_env_dir)
      File.rename(File.join(@test_env_dir, 'simp_hiera3'), @simp_env_dir)
      expect( Simp::Cli::Utils::get_stock_simp_env_datadir ).to eq File.join(@simp_env_dir, 'hieradata')
    end

    it 'returns nil when an env-specific hieradata file exists, but the expected data dir does not' do
      FileUtils.cp_r(File.join(files_dir, 'environments', 'simp'), @test_env_dir)
      FileUtils.mv(File.join(@simp_env_dir, 'data'), File.join(@simp_env_dir, 'hieradata'))
      expect( Simp::Cli::Utils::get_stock_simp_env_datadir ).to be_nil
    end

    it 'returns nil when neither an env-specific hieradata file or the expected Hiera 3 data dir exists' do
      expect( Simp::Cli::Utils::get_stock_simp_env_datadir ).to be_nil
    end
  end

  describe '.validate_password' do
    it 'validates good passwords' do
      expect{ Simp::Cli::Utils.validate_password 'A=V3ry=Go0d=P@ssw0r!' }
        .to_not raise_error
    end

    it 'raises an PasswordError on short passwords' do
      expect{ Simp::Cli::Utils.validate_password 'a@1X' }.to raise_error( Simp::Cli::PasswordError )
    end

    it 'raises an PasswordError on simple passwords' do
      expect{ Simp::Cli::Utils.validate_password 'aaaaaaaaaaaaaaa' }.to raise_error( Simp::Cli::PasswordError )
    end
  end

  describe '.validate_password_with_cracklib' do
    it 'validates good passwords' do
      expect{ Simp::Cli::Utils.validate_password 'A=V3ry=Go0d=P@ssw0r!' }
        .to_not raise_error
    end

    it 'raises an PasswordError on short passwords' do
      expect{ Simp::Cli::Utils.validate_password 'a@1X' }.to raise_error( Simp::Cli::PasswordError )
    end

    it 'raises an PasswordError on simple passwords' do
      expect{ Simp::Cli::Utils.validate_password '012345678901234' }.to raise_error( Simp::Cli::PasswordError )
    end
  end

  describe '.generate_password' do
    it 'is the correct length' do
      expect( Simp::Cli::Utils.generate_password.size )
        .to eq Simp::Cli::Utils::DEFAULT_PASSWORD_LENGTH

      expect( Simp::Cli::Utils.generate_password( 73 ).size ).to eq 73
    end

    it 'does not start or end with a special character' do
      expect( Simp::Cli::Utils.generate_password ).to_not match /^[#%&_.:@-]|[#%&_.:@-]$/
    end
  end

end
