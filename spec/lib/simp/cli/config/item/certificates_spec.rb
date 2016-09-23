require 'simp/cli/config/item/certificates'
require 'simp/cli/config/item/hostname'
require 'rspec/its'
require_relative 'spec_helper'

describe Simp::Cli::Config::Item::Certificates do
  before :each do
    @ci        = Simp::Cli::Config::Item::Certificates.new
    @ci.silent = true
    @hostname  = 'puppet.testing.fqdn'
    item       = Simp::Cli::Config::Item::Hostname.new
    item.value = @hostname
    @ci.config_items[ item.key ] = item

    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )
  end


  describe "#apply" do
    context 'using external files,' do
      before :each do
        @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__),
                                  File.expand_path('tmp', File.dirname( __FILE__ )) )
        @tmp_dirs = {
                      :keydist => File.join( @tmp_dir, 'keydist'),
                      :fake_ca => File.join( @tmp_dir, 'FakeCA'),
                    }
        FileUtils.mkdir @tmp_dirs.values
        src_dir   = File.join(@files_dir,'FakeCA')
        FileUtils.cp_r( Dir["#{src_dir}/*"], @tmp_dirs[:fake_ca] )

        @ci.dirs   = @tmp_dirs
      end

      context "when cert generation is required " do
        it 'generates certs and reports :succeeded status on success' do
          @ci.apply
          expect( @ci.applied_status ).to eq :succeeded
          dir = File.join( @tmp_dirs[:keydist], @hostname )
          expect( File.exists? dir ).to be true
        end

        it 'reports :failed status on failure' do
          ENV['SIMP_CLI_CERTIFICATES_FAIL']='true'
          @ci.apply
          expect( @ci.applied_status ).to eq :failed
        end
      end

      context "when cert generation is not required " do
        it 'reports :unnecessary status' do
          Simp::Cli::Config::Utils.generate_certificates([@hostname], @tmp_dirs[:fake_ca])
          dir = File.join( @tmp_dirs[:keydist], @hostname )
          expect( File.exists? dir ).to be true
          @ci.apply
          expect( @ci.applied_status ).to eq :unnecessary
          expect(@ci.apply_summary).to match /FakeCA certificate generation for puppet.testing.fqdn unnecessary:\n\tcertificates already exist/m
        end
      end

      after :each do
        FileUtils.remove_entry_secure @tmp_dir
        ENV.delete 'SIMP_CLI_CERTIFICATES_FAIL'
      end
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'FakeCA certificate generation for SIMP unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end

