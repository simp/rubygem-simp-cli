require 'simp/cli/config/items/data/cli_has_simp_local_user_from_iso'
require 'test_utils/etc_pwnam_struct'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliHasSimpLocalUserFromIso do
  before :each do
    @ci = Simp::Cli::Config::Item::CliHasSimpLocalUserFromIso.new
  end

  context '#recommended_value' do
    context 'when simp user exists' do
      let(:simp_pwnam) {
        pwnam = TestUtils::EtcPwnamStruct.new
        pwnam.name   = 'simp'
        pwnam.passwd = 'x'
        pwnam.uid    = 1777
        pwnam.gid    = 1777
        pwnam.gecos   = ''
        pwnam.dir    = '/var/local/simp'
        pwnam.shell  = '/bin/bash'
        pwnam
      }

      context 'when ISO install' do
        it "returns 'yes'" do
          allow(Etc).to receive(:getpwnam).and_return(simp_pwnam)
          allow(File).to receive(:exist?).with('/etc/yum.repos.d/simp_filesystem.repo').and_return(true)
          expect( @ci.recommended_value ).to eq('yes')
        end
     end

      context 'not an ISO install' do
        it "returns 'no'" do
          allow(Etc).to receive(:getpwnam).and_return(simp_pwnam)
          allow(File).to receive(:exist?).with('/etc/yum.repos.d/simp_filesystem.repo').and_return(false)
          expect( @ci.recommended_value ).to eq('no')
        end
      end
    end

    context 'when simp user does not exist' do
      it "returns 'no'" do
        allow(Etc).to receive(:getpwnam).and_raise(ArgumentError)
        expect( @ci.recommended_value ).to eq('no')
      end
    end
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
