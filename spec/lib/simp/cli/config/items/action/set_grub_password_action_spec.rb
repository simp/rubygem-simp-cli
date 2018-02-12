require 'simp/cli/config/items/action/set_grub_password_action'
require 'simp/cli/config/items/data/grub_password'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetGrubPasswordAction do
  before :each do
    @ci = Simp::Cli::Config::Item::SetGrubPasswordAction.new
  end

  # TODO: test successes with acceptance tests
  describe '#apply' do
    let(:grub_password) {
      grub_password = Simp::Cli::Config::Item::GrubPassword.new
      grub_password.value = 'vsB2myX+l8-p-FOmbjG%%Exr0R3z8Mkm'
      grub_password
    }

    context 'CentOS 6.x' do
      let(:os_fact)  { { 'release' => { 'major' => '6'} } }

      it 'sets grub password for BIOS boot and sets applied_status to :success' do
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
        allow(File).to receive(:exist?).with('/boot/grub/grub.conf').and_return(true)
        allow(@ci).to receive(:execute).and_return(true)

        @ci.config_items = { grub_password.key => grub_password }
        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
      end

      it 'sets grub password for EFI boot and sets applied_status to :success' do
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
        allow(File).to receive(:exist?).with('/boot/grub/grub.conf').and_return(false)
        allow(File).to receive(:exist?).with('/boot/efi/EFI/redhat/grub.conf').and_return(true)
        allow(@ci).to receive(:execute).and_return(true)

        @ci.config_items = { grub_password.key => grub_password }
        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
      end

      it 'fails when boot file not found' do
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
        allow(File).to receive(:exist?).with('/boot/grub/grub.conf').and_return(false)
        allow(File).to receive(:exist?).with('/boot/efi/EFI/redhat/grub.conf').and_return(false)

        @ci.config_items = { grub_password.key => grub_password }
        expect{ @ci.apply }.to  raise_error(/Could not find grub.conf/)
      end

      it "sets applied_status to :failed when 'sed' command fails" do
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
        allow(File).to receive(:exist?).with('/boot/grub/grub.conf').and_return(false)
        allow(File).to receive(:exist?).with('/boot/efi/EFI/redhat/grub.conf').and_return(true)
        allow(@ci).to receive(:execute).and_return(false)

        @ci.config_items = { grub_password.key => grub_password }
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end

    context 'CentOS 7.x' do
      let(:os_fact)  { { 'release' => { 'major' => '7'} } }

      it 'sets grub password and sets applied_status to :success' do
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
        allow(@ci).to receive(:execute).and_return(true, true)

        @ci.config_items = { grub_password.key => grub_password }
        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
      end

      it "sets applied_status to :failed when 'sed' command fails" do
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
        allow(@ci).to receive(:execute).and_return(false)

        @ci.config_items = { grub_password.key => grub_password }
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end

      it "sets applied_status to :failed when 'grub2-mkconf' command fails" do
        allow(Facter).to receive(:value).with('os').and_return(os_fact)
        allow(@ci).to receive(:execute).and_return(true, false)

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
