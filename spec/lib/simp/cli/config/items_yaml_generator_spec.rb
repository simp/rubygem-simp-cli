require 'simp/cli/config/items_yaml_generator'
require 'rspec/its'
require 'spec_helper'

describe Simp::Cli::Config::ItemsYamlGenerator do
  let (:files_dir) { File.join(__dir__, 'files') }
  describe "#generate_yaml" do
    it "constructs YAML from parts and substitutes variables for 'simp' scenario" do
      expected = IO.read(File.join(files_dir, 'simp_generated_items_tree.yaml'))
      expect( Simp::Cli::Config::ItemsYamlGenerator.new('simp').generate_yaml ).to eq expected
      YAML.load(expected)   # make sure YAML is valid...will raise if parsing fails
    end

    it "constructs YAML from parts and substitutes variables for 'simp_lite' scenario" do
      expected = IO.read(File.join(files_dir, 'simp_lite_generated_items_tree.yaml'))
      expect( Simp::Cli::Config::ItemsYamlGenerator.new('simp_lite').generate_yaml ).to eq expected
      YAML.load(expected)   # make sure YAML is valid...will raise if parsing fails
    end

    it "constructs YAML from parts and substitutes variables for 'poss' scenario" do
      expected = IO.read(File.join(files_dir, 'poss_generated_items_tree.yaml'))
      expect( Simp::Cli::Config::ItemsYamlGenerator.new('poss').generate_yaml ).to eq expected
      YAML.load(expected)   # make sure YAML is valid...will raise if parsing fails
    end

    it 'fails when scenario is invalid' do
      expect{ Simp::Cli::Config::ItemsYamlGenerator.new('oops').generate_yaml }.to raise_error(
        Simp::Cli::Config::ValidationError, "ERROR: Unsupported scenario 'oops'")
    end

    it 'fails when scenario_items.yaml fails to parse' do
      expect{ Simp::Cli::Config::ItemsYamlGenerator.new('malformed', files_dir).generate_yaml }.to raise_error(
        Simp::Cli::Config::InternalError,
       "Internal error: Invalid Items list YAML for 'malformed' scenario")
    end

    it 'fails when scenario_items.yaml is missing name key' do
      bad_yaml = File.join(files_dir, 'missing_name_items.yaml')
      expect{ Simp::Cli::Config::ItemsYamlGenerator.new('missing_name', files_dir).generate_yaml }.to raise_error(
        Simp::Cli::Config::InternalError,
       "Internal error: #{bad_yaml} missing 'name'")
    end

    it 'fails when scenario_items.yaml is missing description key' do
      bad_yaml = File.join(files_dir, 'missing_description_items.yaml')
      expect{ Simp::Cli::Config::ItemsYamlGenerator.new('missing_description', files_dir).generate_yaml }.to raise_error(
        Simp::Cli::Config::InternalError,
       "Internal error: #{bad_yaml} missing 'description'")
    end

    it 'fails when scenario_items.yaml is missing includes key' do
      bad_yaml = File.join(files_dir, 'missing_includes_items.yaml')
      expect{ Simp::Cli::Config::ItemsYamlGenerator.new('missing_includes', files_dir).generate_yaml }.to raise_error(
        Simp::Cli::Config::InternalError,
       "Internal error: #{bad_yaml} missing 'includes'")
    end

    it 'fails when part is invalid' do
      bad_yaml = File.join(files_dir, 'missing_part_items.yaml')
      expect{ Simp::Cli::Config::ItemsYamlGenerator.new('missing_part', files_dir).generate_yaml }.to raise_error(
        Simp::Cli::Config::InternalError,
       "Internal error: Cannot find 'some_missing_part' include for 'missing_part' scenario")
    end
  end
end
