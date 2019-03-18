require File.expand_path( 'errors', __dir__ )
require 'yaml'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config; end

# Builds an Item configuration tree for a scenario
class Simp::Cli::Config::ItemsYamlGenerator


  def initialize(scenario, scenarios_dir=File.join(__dir__, 'scenarios'))
    @scenario = scenario
    @scenarios_dir = scenarios_dir
  end

  def generate_yaml
    scenario_items_hash = load_scenario_items_yaml

    yaml  = "# Generated configuration tree YAML for '#{@scenario}' scenario.\n"
    yaml += "#\n"
    yaml += "---\n"
    scenario_items_hash['includes'].each do |part|
      substitutions = []
      part_name = nil
      if part.is_a?(Hash)
        part_name = part.keys[0]
        substitutions = part[part_name]
      else
        part_name = part
      end

      part_file = File.join(@scenarios_dir, 'parts', part_name)
      unless File.exist?(part_file)
        err_msg = "Cannot find '#{part_name}' include for '#{@scenario}' scenario"
        raise Simp::Cli::Config::InternalError.new(err_msg)
      end

      part_yaml = IO.read(part_file)
      part_yaml = make_substitutions(part_yaml, substitutions) unless substitutions.empty?
      yaml += part_yaml + "\n"
    end
    yaml
  end

  def load_scenario_items_yaml
    scenario_items_file = File.join(@scenarios_dir, "#{@scenario}_items.yaml")
    if File.exist?(scenario_items_file)
      scenario_yaml  = IO.read(scenario_items_file)
    else
      raise Simp::Cli::Config::ValidationError.new("ERROR: Unsupported scenario '#{@scenario}'")
    end

    begin
      scenario_items_hash = YAML.load scenario_yaml
    rescue Psych::SyntaxError => e
      $stderr.puts "Invalid '#{@scenario} 'scenario Items YAML: #{e.message}"
      raise Simp::Cli::Config::InternalError.new("Invalid Items list YAML for '#{@scenario}' scenario")
    end

    unless scenario_items_hash['name']
      raise Simp::Cli::Config::InternalError.new("#{scenario_items_file} missing 'name'")
    end

    unless scenario_items_hash['description']
      raise Simp::Cli::Config::InternalError.new("#{scenario_items_file} missing 'description'")
    end

    unless scenario_items_hash['includes']
      raise Simp::Cli::Config::InternalError.new("#{scenario_items_file} missing 'includes'")
    end

    scenario_items_hash
  end

  def make_substitutions(yaml, substitutions)
    new_yaml = yaml.dup
    substitutions.each do |sub_hash|
      key = sub_hash.keys[0]
      new_yaml.gsub!("%#{key}%", sub_hash[key])
    end
    return new_yaml
  end
end
