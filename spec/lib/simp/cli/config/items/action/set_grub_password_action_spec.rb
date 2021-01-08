require 'simp/cli/config/items/action/set_grub_password_action'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetGrubPasswordAction do
  before :each do
    stub_const('Simp::Cli::SIMP_MODULES_INSTALL_PATH', '')
    @puppet_env_info = {
      :puppet_config => { 'modulepath' => '/some/module/path' }
    }
    @ci = Simp::Cli::Config::Item::SetGrubPasswordAction.new(@puppet_env_info)
  end

  # TODO: test successes with acceptance tests
  describe '#apply' do
    let(:grub_password) {
      grub_password = Simp::Cli::Config::Item::GrubPassword.new(@puppet_env_info)
      grub_password.value = 'vsB2myX+l8-p-FOmbjG%%Exr0R3z8Mkm'
      grub_password
    }


    context 'CentOS 7.x' do
      let(:os_fact)  { { 'release' => { 'major' => '7'} } }

      it 'calls puppet apply and sets applied_status to :success' do
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
        apply_command = [
          'puppet apply',
          '--modulepath=/some/module/path',
          '--digest_algorithm=sha256',
          "-e \"grub_user { 'root': password => '#{grub_password.value}', superuser => true }\""
        ].join(' ')
        allow(@ci).to receive(:execute).with(apply_command).and_return(true)

        @ci.config_items = { grub_password.key => grub_password }
        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
      end

      it "sets applied_status to :failed when  puppet apply fails" do
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
        allow(@ci).to receive(:execute).and_return(false)

        @ci.config_items = { grub_password.key => grub_password }
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq(
        'Setting of GRUB password unattempted')
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
