require 'simp/cli/utils'
require 'rspec/its'
require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Utils do

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
