require 'simp/cli/config/items/data/cli_local_priv_user_password'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliLocalPrivUserPassword do
  before :each do
    @ci = Simp::Cli::Config::Item::CliLocalPrivUserPassword.new
    @ci.silent = true
  end

  describe '#query_prompt' do
    it 'returns a value that uses cli::local_priv_user when available' do
      item = Simp::Cli::Config::Item::CliLocalPrivUser.new
      item.value = 'local_admin'
      @ci.config_items[item.key] = item
      expect( @ci.query_prompt ).to eq "'local_admin' password"
    end

    it 'fails when cli::local_priv_user is missing' do
      expect { @ci.query_prompt }.to raise_error(Simp::Cli::Config::InternalError,
        /Simp::Cli::Config::Item::CliLocalPrivUserPassword could not find cli::local_priv_user/)
    end
  end

  describe '#validate' do
    context 'when password has not been preassigned' do
      it 'validates valid password' do
        expect( @ci.validate('a!S@d3F$g5H^j&k') ).to eq true
      end

      it "doesn't validate empty passwords" do
        expect( @ci.validate('') ).to eq false
      end
    end

    # preassignment happens when values are loaded in from an answers file
    # or from key/value pairs on the command line
    context 'when password has been preassigned' do
      it 'validates valid password hash' do
        password_hash = '$6$somesalt$xK8qDo8XIAgPi.kqwyaXRXvyb6kUTZGisSL7HFiC4pQ7OEvk70x9v9P8dKjWsUni6qJT44R7rbx3YDQBT6ho50'
        @ci.value = password_hash
        expect( @ci.validate(password_hash) ).to eq true
      end

      it "doesn't validate a plain password" do
        plain_password = 'a!S@d3F$g5H^j&k'
        @ci.value = plain_password
        expect( @ci.validate(plain_password) ).to eq false
      end
    end
  end

  describe '#encrypt' do
    it 'generates a SHA512 encrypted password' do
      password = 'a!S@d3F$g5H^j&k'
      encrypted = @ci.encrypt(password)
      expect( Simp::Cli::Config::Utils.validate_password_sha512(encrypted) ).to be true
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
