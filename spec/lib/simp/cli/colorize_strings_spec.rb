# frozen_string_literal: true

require 'spec_helper'
require 'simp/cli/colorize_strings'

describe 'simp/cli/colorize_strings' do
  it 'adds the HighLine color methods to String' do
    expect('x'.red).to eq("\e[31mx\e[0m")
  end

  it 'keeps the core String#clear' do
    s = +'abc'
    expect(s.clear).to equal(s)
    expect(s).to be_empty
  end

  it 'keeps the core String#reverse' do
    expect('abc'.reverse).to eq('cba')
  end
end
