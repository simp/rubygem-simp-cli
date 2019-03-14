require 'simp/cli/puppetfile/skeleton'
require 'spec_helper'

describe Simp::Cli::Puppetfile::Skeleton do
  describe '.to_puppetfile' do
    subject(:to_puppetfile) { described_class.to_puppetfile }
    it { is_expected.to match /^instance_eval\(File\.read\("Puppetfile\.simp"\)\)/ }
  end
end
