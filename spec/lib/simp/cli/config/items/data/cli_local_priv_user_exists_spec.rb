require 'simp/cli/config/items/data/cli_local_priv_user_exists'
require 'test_utils/etc_pwnam_struct'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliLocalPrivUserExists do

  before :each do
    @ci = Simp::Cli::Config::Item::CliLocalPrivUserExists.new

    item = Simp::Cli::Config::Item::CliLocalPrivUser.new
    item.value = 'local_admin'
    @ci.config_items[item.key] = item
  end

  context '#recommended_value' do
    context 'when local privileged user exists' do
      let(:local_admin_pwnam) {
        pwnam = TestUtils::EtcPwnamStruct.new
        pwnam.name   = 'local_admin'
        pwnam.passwd = 'x'
        pwnam.uid    = 1778
        pwnam.gid    = 1778
        pwnam.gecos   = ''
        pwnam.dir    = '/var/local/local_admin'
        pwnam.shell  = '/bin/bash'
        pwnam
      }

      it "returns 'yes'" do
        allow(Etc).to receive(:getpwnam).and_return(local_admin_pwnam)
        expect( @ci.recommended_value ).to eq('yes')
      end
    end

    context 'when local privileged user does not exist' do
      it "returns 'no'" do
        allow(Etc).to receive(:getpwnam).and_raise(ArgumentError)
        expect( @ci.recommended_value ).to eq('no')
      end
    end
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
