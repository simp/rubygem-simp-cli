require 'simp/cli/config/item/use_fips'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::UseFips do
  before :each do
    @ci = Simp::Cli::Config::Item::UseFips.new
  end

  describe "#validate" do
    it "validates yes/no" do
      expect( @ci.validate 'yes' ).to eq true
      expect( @ci.validate 'y' ).to   eq true
      expect( @ci.validate 'Y' ).to   eq true
      expect( @ci.validate 'no' ).to  eq true
      expect( @ci.validate 'n' ).to   eq true
      expect( @ci.validate 'NO' ).to  eq true
      expect( @ci.validate true ).to  eq true
      expect( @ci.validate false ).to eq true
    end

    it "doesn't validate other things" do
      expect( @ci.validate 'ydd' ).to  eq false
      expect( @ci.validate 'gsdg' ).to eq false
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq(
        'Need for digest algorithm adjustment for FIPS not evaluated')
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
