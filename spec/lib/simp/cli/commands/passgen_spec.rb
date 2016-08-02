require 'simp/cli/commands/passgen'
require_relative( '../spec_helper' )


describe Simp::Cli::Commands::Passgen do
  describe ".run" do
    it "requires valid target passgen dir" do
      expect { Simp::Cli::Commands::Passgen.run([]) }.to raise_error(RuntimeError)
      expect { Simp::Cli::Commands::Passgen.run(['-l']) }.to raise_error(RuntimeError)
      expect { Simp::Cli::Commands::Passgen.run(['-d', '/oops']) }.to raise_error(OptionParser::ParseError)
    end
  end
end
