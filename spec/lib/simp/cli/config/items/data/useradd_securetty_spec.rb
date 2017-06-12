require 'simp/cli/config/items/data/useradd_securetty'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::UseraddSecuretty do
  before :each do
    @ci = Simp::Cli::Config::Item::UseraddSecuretty.new
    @ci.silent = true
  end

  describe '#recommended_value' do
    it 'returns []' do
      expect( @ci.recommended_value ).to eq []
    end
  end

  describe '#validate_item' do
    it 'validates console' do
      expect( @ci.validate_item('console') ).to eq true
    end

    it 'validates any explicit tty' do
      expect( @ci.validate_item('tty0') ).to eq true
      expect( @ci.validate_item('tty68') ).to eq true
      expect( @ci.validate_item('ttyS3') ).to eq true
    end

    it 'rejects current tty' do
      expect( @ci.validate_item('tty') ).to eq false
    end

    it 'rejects invalid tty' do
      expect( @ci.validate_item('oops') ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
