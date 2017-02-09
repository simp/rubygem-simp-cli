require 'simp/cli/commands/passgen'
require 'simp/cli/lib/utils'
require 'spec_helper'


describe Simp::Cli::Commands::Passgen do
  describe ".run" do
    before :each do
      @tmp_dir   = Dir.mktmpdir(File.basename(__FILE__) )
      allow(::Utils).to receive(:puppet_info).and_return( {
        :config => {
          'codedir' => @tmp_dir,
          'confdir' => @tmp_dir
        },
        :environment_path => File.join(@tmp_dir, 'environments'),
        :simp_environment_path => File.join(@tmp_dir, 'environments', 'simp'),
        :fake_ca_path => File.join(@tmp_dir, 'environments', 'simp', 'FakeCA')
      } )
    end

    after :each do
      Simp::Cli::Commands::Passgen.reset_options
    end

    it "requires target passgen dir to be specified" do
      expect { Simp::Cli::Commands::Passgen.run([]) }.to raise_error(RuntimeError,
        'The SIMP Passgen Tool requires at least one argument to work')

      expect { Simp::Cli::Commands::Passgen.run(['-l']) }.to raise_error(OptionParser::ParseError,
        /Could not find a target passgen directory, please specify one with the `\-d` option/)
    end

    it "requires valid target passgen dir" do
      expect { Simp::Cli::Commands::Passgen.run(['-d', '/oops']) }.to raise_error(RuntimeError,
        "Target directory '/oops' does not exist")
    end
  end
end
