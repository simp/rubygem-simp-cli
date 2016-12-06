require 'simp/cli/config/items/action/copy_simp_to_environments_action'
require 'fileutils'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::CopySimpToEnvironmentsAction do
  before :each do
    @ci = Simp::Cli::Config::Item::CopySimpToEnvironmentsAction.new
  end

  #TODO This class needs to be tested via an acceptance test.  The tests
  # below are not very meaningful.
  context '#apply' do
    before :each do
      @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
      @source_dir = File.join(@tmp_dir, 'share', 'simp')
      @dest_dir = File.join(@tmp_dir, 'environments', 'simp')
      @adapter_config = File.join(@tmp_dir, 'adapter_config.yaml')

      # create sparse environments/simp tree
      FileUtils.mkdir_p(@source_dir)
      FileUtils.mkdir_p(File.join(@source_dir, 'environments', 'simp'))
      FileUtils.touch(File.join(@source_dir, 'environments', 'simp', 'environment.conf'))

      # create sparse modules tree
      FileUtils.mkdir_p(File.join(@source_dir, 'modules', 'pam'))
      FileUtils.touch(File.join(@source_dir, 'modules', 'pam', 'CHANGELOG'))
      FileUtils.mkdir_p(File.join(@source_dir, 'modules', 'simplib'))
      FileUtils.touch(File.join(@source_dir, 'modules', 'simplib', 'metadata.json'))
      
      FileUtils.mkdir_p(File.dirname(@dest_dir))

      @ci.adapter_config = @adapter_config
      @ci.source_dir = @source_dir
      @ci.dest_dir = @dest_dir
      @ci.copy_script = File.join(File.dirname(__FILE__), 'files', 'simp_adapter',
        'mock_simp_rpm_helper.rb')
    end

    context 'when copy operation succeeds' do
      it 'reports succeeded status' do
        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
      end
    end

    context 'when simp environment copy fails ' do
      it 'reports failed status' do
        ENV['MOCK_SIMP_RPM_HELPER_FAIL'] = 'simp'
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end

    context 'when a simp module copy fails ' do
      it 'reports failed status' do
        ENV['MOCK_SIMP_RPM_HELPER_FAIL'] = 'simplib'
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end
  end

  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
