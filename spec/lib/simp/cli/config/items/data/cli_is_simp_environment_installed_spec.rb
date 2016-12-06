require 'simp/cli/config/items/data/cli_is_simp_environment_installed'
require 'fileutils'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CliIsSimpEnvironmentInstalled do
  before :each do
    @ci = Simp::Cli::Config::Item::CliIsSimpEnvironmentInstalled.new
  end

  context '#recommended_value' do
    before :each do
      @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
      @adapter_config = File.join(@tmp_dir, 'adapter_config.yaml')
      @ci.adapter_config = @adapter_config
    end

    context 'when adapter_config.yaml exists and copy_rpm_data = true' do
      it "returns 'yes'" do
        File.open(@adapter_config, 'w') do |file| file.puts <<EOM
---
copy_rpm_data : true
EOM
        end
        expect( @ci.recommended_value ).to eq('yes')
      end
    end

    context 'when adapter_config.yaml exists and copy_rpm_data = false' do
      it "returns 'no'" do
        File.open(@adapter_config, 'w') do |file| file.puts <<EOM
---
copy_rpm_data : false
EOM
        end
        expect( @ci.recommended_value ).to eq('no')
      end
    end

    context 'when adapter_config.yaml does not exist ' do
      it "assumes R10K install and returns 'yes'" do
        expect( @ci.recommended_value ).to eq('yes')
      end
    end

    context 'when adapter_config.yaml is malformed' do
      it "returns 'no'" do
        File.open(@adapter_config, 'w') do |file| file.puts <<EOM
--- `
EOM
        end
        expect( @ci.recommended_value ).to eq('no')
      end
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end
  end

  it_behaves_like 'a yes/no validator'
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
