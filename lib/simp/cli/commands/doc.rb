module Simp::Cli::Commands; end

class Simp::Cli::Commands::Doc < Simp::Cli
  def self.run(args = Array.new)
    raise "Package 'simp-doc' is not installed, cannot continue" unless system("rpm -q --quiet simp-doc")
    pupdoc = %x{rpm -ql simp-doc | grep html/index.html$ | head -1}.strip.chomp
    raise "Could not find the SIMP documentation. Please ensure that you can access '#{pupdoc}'." unless File.exists?(pupdoc)
    exec("links #{pupdoc}")
  end

  def self.help
    puts "\n=== The SIMP Doc Tool ===\nShow SIMP documentation in elinks"
  end
end
