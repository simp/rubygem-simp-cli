require 'simp/cli/commands/command'

class Simp::Cli::Commands::Doc < Simp::Cli::Commands::Command

  def help
    puts "\n=== The SIMP Doc Tool ===\nShow SIMP documentation in elinks, a text-based web browser"
  end

  def run(unused_args = [])
    unless system("rpm -q --quiet simp-doc")
      err_msg = "Package 'simp-doc' is not installed, cannot continue."
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    main_page = %x{rpm -ql simp-doc | grep html/index.html$ | head -1}.strip.chomp

    unless File.exists?(main_page)
      err_msg = "Could not find the SIMP documentation. Please ensure that you can access '#{main_page}'."
      raise Simp::Cli::ProcessingError.new(err_msg)
    end

    exec("links #{main_page}")
  end
end
