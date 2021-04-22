require 'simp/cli/config/items/list_item'
require 'rspec/its'
require 'spec_helper'

describe Simp::Cli::Config::ListItem do
  before :each do
    @ci = Simp::Cli::Config::ListItem.new
  end

  describe 'constructor' do
    it 'does not allow empty lists by default' do
      expect(@ci.allow_empty_list).to be false
    end
  end

  describe '#default_value_noninteractive' do
    it 'returns [] when default_value()=nil and empty lists are allowed' do
      #  @ci.default_value will return nil, because ListItem does not override
      #  Item#get_recommended_value
      @ci.allow_empty_list = true
      expect( @ci.default_value_noninteractive ).to eq([])
    end

    it 'returns nil when default_value()=nil and empty lists are not allowed' do
      expect( @ci.default_value_noninteractive ).to be_nil
    end

    it 'returns default_value() otherwise' do
      @ci.allow_empty_list = true
      expect(@ci).to receive(:default_value).and_return(['default','array'])
      expect( @ci.default_value_noninteractive ).to eq(['default','array'])
    end
  end

  describe '#instructions' do
    it "returns 'skip' instructions when default_value()=nil" do
      instr = @ci.instructions
      expect(instr).to match(/Enter a space-delimited list \(hit enter to skip\)/)
    end

    it "returns 'accept default value' instructions when default_value is set" do
      expect(@ci).to receive(:default_value).and_return(['default','array'])
      instr = @ci.instructions
      expect(instr).to match(/Enter a space-delimited list \(hit enter to accept default value\)/)
    end
  end

  describe '#highline_question_type' do
    it 'converts a String with one values into an Array' do
      list = @ci.highline_question_type.call('default')
      expect(list).to eq(['default'])
    end

    it 'converts a String with multiple space-separated values into an Array' do
      list = @ci.highline_question_type.call('default array')
      expect(list).to eq(['default', 'array'])
    end

    it 'converts a String with multiple comma-separated values into an Array' do
      list = @ci.highline_question_type.call('default,array')
      expect(list).to eq(['default', 'array'])
    end
  end

  describe '#validate' do
    it 'returns true for nil value when empty lists are allowed' do
      @ci.allow_empty_list = true
      expect( @ci.validate(nil) ).to be true
    end

    it 'returns false for nil value when empty lists are not allowed' do
      expect( @ci.validate(nil) ).to be false
    end

    it 'returns false for [] value when empty lists are not allowed' do
      expect( @ci.validate([]) ).to be false
    end

    it 'returns false if any array item is invalid' do
      expect(@ci).to receive(:validate_item).and_return(true,false)
      expect( @ci.validate(['good1', 'bad', 'good2']) ).to be false
    end

    it 'returns true if all array items are valid' do
      expect(@ci).to receive(:validate_item).and_return(true,true)
      expect( @ci.validate(['good1', 'good2']) ).to be true
    end
  end
end
