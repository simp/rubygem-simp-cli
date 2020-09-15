require 'simp/cli/config/items/action_item'
require_relative 'spec_helper'

class MyActionItem < Simp::Cli::Config::ActionItem
  attr_accessor :apply_action

  def initialize
    super
    @key = 'my::action::item'
    @description = 'enable my success'
    @apply_action = :succeed
    @allow_user_apply = true
  end

  def apply
    case @apply_action
    when :succeed
      @applied_status = :succeeded
    when :fail_no_raise
      @applied_status = :failed
    when :fail_raise
      raise 'MyActionItem error occurred'
    end
  end

  def apply_summary
    "Action for #{@key} #{@applied_status}"
  end
end

describe Simp::Cli::Config::ActionItem do
  describe '#initialize' do
    it "has 'unattempted' applied_status when initialized" do
      ci = Simp::Cli::Config::ActionItem.new
      expect( ci.applied_status ).to eq :unattempted
    end
  end

  describe '#apply' do
    it 'succeeds when apply() succeeds' do
      ci = MyActionItem.new

      ci.safe_apply
      expect(ci.applied_status).to eq :succeeded
    end

    it 'fails when @die_on_apply_fail=false and apply() fails' do
      ci = MyActionItem.new
      ci.apply_action = :fail_no_raise

      ci.safe_apply
      expect(ci.applied_status).to eq :failed
    end

    it 'fails when @die_on_apply_fail=true and apply() raises an exception' do
      ci = MyActionItem.new
      ci.apply_action = :fail_raise

      ci.safe_apply
      expect(ci.applied_status).to eq :failed
    end

    it 'raises ApplyError when @die_on_apply_fail=true and apply() fails' do
      ci = MyActionItem.new
      ci.die_on_apply_fail = true
      ci.apply_action = :fail_no_raise

      expect { ci.safe_apply }.to raise_error(Simp::Cli::Config::ApplyError,
        'Action for my::action::item failed')
      expect(ci.applied_status).to eq :failed
    end

    it 'raises ApplyError when @die_on_apply_fail=true and apply() raises an exception' do
      ci = MyActionItem.new
      ci.die_on_apply_fail = true
      ci.apply_action = :fail_raise

      expect { ci.safe_apply }.to raise_error(Simp::Cli::Config::ApplyError,
       'MyActionItem error occurred')

      expect(ci.applied_status).to eq :failed
    end

  end
end
