require 'simp/cli/config/items/data/simp_options_puppet_ca_port'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpOptionsPuppetCAPort do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpOptionsPuppetCAPort.new
  end

  describe '#validate' do
    it 'validates acceptable ca ports' do
      expect( @ci.validate '8140' ).to eq true
      expect( @ci.validate '8141' ).to eq true
    end

    it "doesn't validate bad ca ports" do
      expect( @ci.validate 'puppet' ).to eq false
      expect( @ci.validate '70000' ).to eq false
    end
  end

  describe '#recommended_value' do
    it 'returns 8141' do
      expect( @ci.recommended_value ).to eq 8141
    end

    context 'when in FOSS' do
      before(:each) do
        allow(Simp::Cli::Utils).to receive(:puppet_info).and_return({:is_pe => false})
        allow_any_instance_of(Simp::Cli::Utils).to receive(:puppet_info).and_return({:is_pe => false})
      end

      it 'returns 8141' do
        expect( Simp::Cli::Config::Item::SimpOptionsPuppetCAPort.new.recommended_value ).to eq 8141
      end
    end

    context 'when in PE' do
      before(:each) do
        allow(Simp::Cli::Utils).to receive(:puppet_info).and_return({:is_pe => true})
        allow_any_instance_of(Simp::Cli::Utils).to receive(:puppet_info).and_return({:is_pe => true})
      end

      it 'returns 8140' do
        expect( Simp::Cli::Config::Item::SimpOptionsPuppetCAPort.new.recommended_value ).to eq 8140
      end
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
