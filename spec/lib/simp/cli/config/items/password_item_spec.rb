# frozen_string_literal: true

require 'simp/cli/config/items/password_item'
require 'rspec/its'
require 'spec_helper'

describe Simp::Cli::Config::PasswordItem do
  before :each do
    @ci        = described_class.new
    @ci.silent = true
  end

  it 'validates good passwords' do
    expect(@ci.validate('A=Re@lly=S_6duP3rP@ssw0r!')).to be true
  end

  it "doesn't validate bad passwords" do
    expect(@ci.validate('short')).to     be false
    expect(@ci.validate('')).to          be false
    expect(@ci.validate('123456789')).to be false
  end
end
