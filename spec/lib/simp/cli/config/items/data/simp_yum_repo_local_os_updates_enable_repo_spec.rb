# frozen_string_literal: true

require 'simp/cli/config/items/data/simp_yum_repo_local_os_updates_enable_repo'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SimpYumRepoLocalOsUpdatesEnableRepo do
  before :each do
    @ci = described_class.new
  end

  describe '#recommended_value' do
    it "returns 'no'" do
      expect(@ci.recommended_value).to eq('no')
    end
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
