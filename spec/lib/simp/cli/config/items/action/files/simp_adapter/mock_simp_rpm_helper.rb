#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'

options = OpenStruct.new
parser = OptionParser.new do |opts|
  opts.on(
    "--rpm_dir PATH",
    "The directory into which the RPM source material is installed"
  ) do |arg|
    options.rpm_dir = arg.strip
    options.module_name = File.basename(options.rpm_dir)
  end

  opts.on(
    "--rpm_section SECTION",
    "The section of the RPM from which the script is being called.",
    "    Must be one of 'pre', 'post', 'preun', 'postun'"
  ) do |arg|
    options.rpm_section = arg.strip
  end

  opts.on(
    "--rpm_status STATUS",
    "The status code passed to the RPM section"
  ) do |arg|
    options.rpm_status = arg.strip
  end

  opts.on(
      "-t DIR",
      "--target_dir DIR",
      "The target directory"
    ) do |arg|
      options.target_dir = arg.strip
  end
end

begin
  parser.parse!(ARGV)
rescue OptionParser::ParseError => e
  $stderr.puts e
  $stdout.puts parser
  exit 1
end

if ENV['MOCK_SIMP_RPM_HELPER_FAIL'] == options.module_name
  exit 1
else
  exit 0
end
