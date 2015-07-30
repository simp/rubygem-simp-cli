require 'simp/cli/config/item/remove_ldap'

require 'simp/cli/config/item/use_ldap'

require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::RemoveLdap do
  before :each do
    @ci = Simp::Cli::Config::Item::RemoveLdap.new
  end

  # TODO: how to test this?
  describe "#apply" do

    it "detects the file being absent" do
      skip "TODO: will finish this, look at yum_repositories_spec"
    end

    it "will do everything right" do
      skip "FIXME: how shall we test RemoveLdap#apply()?"
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
