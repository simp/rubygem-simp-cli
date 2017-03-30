require 'simp/cli/config/items/data/svckill_mode'
require 'fileutils'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SvckillMode do
  before :each do
    @ci = Simp::Cli::Config::Item::SvckillMode.new
  end

  context '#recommended_value' do
    it "returns 'warning'" do
      expect( @ci.recommended_value ).to eq('warning')
    end
  end

  context '#validate' do
    it "validates 'enforcing'" do
      expect( @ci.validate('enforcing') ).to eq true
    end

    it "validates 'warning'" do
      expect( @ci.validate('warning') ).to eq true
    end

    it "rejects invalid mode " do
      expect( @ci.validate('warn') ).to eq false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
