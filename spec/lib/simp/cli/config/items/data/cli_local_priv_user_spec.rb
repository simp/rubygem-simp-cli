# frozen_string_literal: true

require 'simp/cli/config/items/data/cli_local_priv_user'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliLocalPrivUser do
  before :each do
    @ci = described_class.new
  end

  describe '#validate' do
    it 'validates valid usernames' do
      expect(@ci.validate('admin')).to be true
      expect(@ci.validate('user_admin1')).to be true
      expect(@ci.validate('user3-special')).to be true
      expect(@ci.validate('_admin$')).to be true
    end

    it "doesn't validate invalid usernames" do
      expect(@ci.validate('1admin')).to be false
      expect(@ci.validate('Admin')).to be false
      expect(@ci.validate('this_is_longer_than_32_characters')).to be false
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
