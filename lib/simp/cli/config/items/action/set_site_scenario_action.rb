require_relative '../action_item'
require_relative '../data/cli_simp_scenario'
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SetSiteScenarioAction < ActionItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key                   = 'puppet::site::scenario'
      @description           = "Set $simp_scenario in simp environment's site.pp"
      @category              = :puppet_env
    end

    def apply
      @applied_status = :failed

      simp_scenario = get_item('cli::simp::scenario').value
      site_pp = File.join(@puppet_env_info[:puppet_env_dir], 'manifests', 'site.pp')
      if File.exist?(site_pp)
        backup_file = "#{site_pp}.#{@start_time.strftime('%Y%m%dT%H%M%S')}"
        info( "Backing up #{site_pp} to #{backup_file}" )
        FileUtils.cp(site_pp, backup_file)
        group_id = File.stat(site_pp).gid
        File.chown(nil, group_id, backup_file)

        info( "Updating $simp_scenario in #{site_pp}" )
        simp_scenario_line_found = false
        lines = IO.readlines(site_pp)
        File.open(site_pp, "w") do |f|
          lines.each do |line|
            line.chomp!
            if line =~ /^\$simp_scenario\s*=/
              simp_scenario_line_found = true
              f.puts "$simp_scenario = '#{simp_scenario}'"
            else
              f.puts line
            end
          end
        end
        if simp_scenario_line_found
          @applied_status = :succeeded
        else
          error( "\nERROR: $simp_scenario not found in #{site_pp}", [:RED] )
        end
      else
        error( "\nERROR: #{site_pp} not found", [:RED] )
      end
    end

    def apply_summary
      "Setting of $simp_scenario in the simp environment's site.pp #{@applied_status}"
    end
  end
end
