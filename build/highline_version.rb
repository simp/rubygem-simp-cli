# frozen_string_literal: true

# The highline version the RPM bundles, read from the RPM spec file's
# `%global highline_version`. The Rakefile builds the bundled gem at this
# version and the Gemfile tests against it, so the spec is the one place to
# change it (Renovate updates it there).
module SimpCliBuild
  SPEC_FILE = File.join(__dir__, 'rubygem-simp-cli.spec')

  def self.highline_version
    version = File.read(SPEC_FILE)[%r{^%global\s+highline_version\s+(\S+)\s*$}, 1]
    raise "Could not find '%global highline_version <version>' in #{SPEC_FILE}" if version.nil?
    raise "Invalid highline_version '#{version}' in #{SPEC_FILE}: expected a release number like 2.0.3" unless version.match?(%r{\A\d+(?:\.\d+)*\z})

    version
  end
end
