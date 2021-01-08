require 'simp/cli/config/items/data/grub_password'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::GrubPassword do
  before :each do
    @ci = Simp::Cli::Config::Item::GrubPassword.new
    @ci.silent = true
  end

  describe "#encrypt" do
    # NOTE: not much we can test
    it "encrypts grub_passwords" do
      crypted_pw = @ci.encrypt( 'foo' )
      skip "TODO: define tests for EL7+ grub passwords"
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
