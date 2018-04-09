require 'simp/cli/config/items/password_item'
require 'rspec/its'
require 'spec_helper'

describe Simp::Cli::Config::PasswordItem do
  before :each do
    @ci        = Simp::Cli::Config::PasswordItem.new
    @ci.silent = true
  end

  it "validates good passwords" do
    expect( @ci.validate( 'A=Re@lly=S_6duP3rP@ssw0r!' ) ).to eq true
  end

  it "doesn't validate bad passwords" do
    expect( @ci.validate( 'short' ) ).to     eq false
    expect( @ci.validate( '' ) ).to          eq false
    expect( @ci.validate( '123456789' ) ).to eq false
  end
end
