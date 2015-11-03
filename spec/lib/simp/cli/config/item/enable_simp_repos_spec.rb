require 'simp/cli/config/item/enable_simp_repos'
require 'simp/cli/config/item/is_master_yum_server'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::EnableSimpRepos do
  before :each do
    @ci        = Simp::Cli::Config::Item::EnableSimpRepos.new
    @ci.silent = true
  end

  describe "#value (after #query)" do
    context "when is_master_yum_server is true" do
      it "it is false" do
        item             = Simp::Cli::Config::Item::IsMasterYumServer.new
        item.value       = true
        @ci.config_items[item.key] = item
        @ci.query
        expect( @ci.value ).to  eq false
      end
    end
    context "when is_master_yum_server is false" do
      it "it is true" do
        item             = Simp::Cli::Config::Item::IsMasterYumServer.new
        item.value       = false
        @ci.config_items[item.key] = item
        @ci.query
        expect( @ci.value ).to  eq true
      end
    end

    it_behaves_like "a child of Simp::Cli::Config::Item"
  end
end
