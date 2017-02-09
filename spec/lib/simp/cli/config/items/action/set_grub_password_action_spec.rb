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
    pending 'sets grub password for CentOS 6.x'
    pending 'sets grub password for CentOS 7.x'
    it 'sets applied_status to :failed when fails to set grub password ' do
      skip("Test can't be run as root") if ENV.fetch('USER') == 'root'
      grub_password = Simp::Cli::Config::Item::GrubPassword.new
      grub_password.value =  'vsB2myX+l8-p-FOmbjG%%Exr0R3z8Mkm'
      @ci.config_items = { grub_password.key => grub_password }
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
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
