require 'simp/cli/config/items/data/simp_grub_password'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpGrubPassword do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpGrubPassword.new
    @ci.silent = true
  end

  describe '#encrypt' do
    let(:encrypt_exe) { '/usr/bin/grub2-mkpasswd-pbkdf2' }

    context 'when grub2-mkpasswd-pbkdf2 exists' do
      it 'encrypts the GRUB password' do
        expect(File).to receive(:exist?).with(encrypt_exe).and_return(true)
        cmd = "#{encrypt_exe} <<EOM\nfoo\nfoo\nEOM"
        encrypted_pw = 'grub.pbkdf2.sha512.10000.6221758C701AAB3A966FF164AF9DEDA009AF3EF9C8409D612467D67A11E59D2223CD2403497319F08C9A37CAEA59B3126E266A4B8DF96691429D0FC919CCBC37.D3DD42C6340D8CEDC71290E4BDE26EF1EFF064DDA10F650E17253B63BA673159E173D82B28FA89C99BEE81C0A34F84FF3EA08BC56CCF79632AC49FD2FD3F59A6'
        result = "PBKDF2 hash of your password is #{encrypted_pw}"
        expect(@ci).to receive(:`).with(cmd).and_return(result)
        crypted_pw = @ci.encrypt( 'foo' )
        expect(crypted_pw).to eq encrypted_pw
      end
    end

    context 'when grub2-mkpasswd-pbkdf2 exists' do
      it 'fails to encrypt grub_passwords' do
        expect(File).to receive(:exist?).with(encrypt_exe).and_return(false)
        expect{ @ci.encrypt( 'foo' ) }.to raise_error(Simp::Cli::ProcessingError,
          "Failed to encrypt GRUB password: #{encrypt_exe} does not exist")
      end
    end
  end

  describe '#validate' do
    context 'password has not been preassigned' do
      it 'validates valid password' do
        expect( @ci.validate 'a!S@d3F$g5H^j&k' ).to eq true
      end

      it "doesn't validate empty passwords" do
        expect( @ci.validate '' ).to eq false
      end
    end

    context 'password has been preassigned' do
      it 'validates an encrypted password' do
        encrypted_pw = 'grub.pbkdf2.sha512.10000.D0CCB6553D29D3C25284D4FB8967ABF87E69ABD415F3E71668B7ADAD81FCBF47471C3CC45E48203754AD79A76BDBA07392124EAA53FE837CEE99CFE45E7881B0.939C311509D96842FD8E1CA2EE8F24E91084619730A7A1EDC7E76D00955DEA3B3BB78CD8B7A54FEAAE37FE5C79A108AF2BF6FCD1A5EEABDED3ABABBA3FC0398A'

        @ci.value = encrypted_pw
        expect( @ci.validate encrypted_pw ).to eq true
      end

      it "doesn't validate an unencrypted password" do
        @ci.value = 'a!S@d3F$g5H^j&k'
        expect( @ci.validate 'a!S@d3F$g5H^j&k' ).to eq false
      end
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
