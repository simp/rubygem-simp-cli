# frozen_string_literal: true

gem_sources = ENV.fetch('GEM_SERVERS', 'https://rubygems.org').split(%r{[, ]+})

gem_sources.each { |gem_source| source gem_source }

# read dependencies in from the gemspec
gemspec

# mandatory gems
gem 'bundler'
gem 'highline', :path => 'ext/gems/highline'
# highline requires abbrev, which is no longer a default gem in Ruby >= 3.4
gem 'abbrev'
# Required for Ruby >= 3.4
gem 'syslog', require: false
# Ruby 3.4+ removed 'observer' from default gems, but 'drb' (pulled in by
# rspec/beaker dependencies) still requires it.
gem 'observer', require: false
# renovate: datasource=rubygems versioning=ruby
gem 'openvox', ENV.fetch('OPENVOX_VERSION', ENV.fetch('PUPPET_VERSION', ['>= 8', '< 9']))
# renovate: datasource=rubygems versioning=ruby
gem 'simp-rake-helpers', ENV.fetch('SIMP_RAKE_HELPERS_VERSION', '~> 6.0')

# renovate: datasource=rubygems versioning=ruby
gem 'r10k', ENV.fetch('R10K_VERSION', ENV.fetch('R10k_VERSION', '~> 5'))
# renovate: datasource=rubygems versioning=ruby
gem 'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', '~> 3.0')

group :testing do
  # to parse YUM repo files in `simp config` test
  gem 'inifile'

  # bootstrap common environment variables
  gem 'dotenv'

  # Ruby code coverage
  gem 'simplecov'

  # Testing framework
  gem 'rspec'
  gem 'rspec-its'
end

# nice-to-have gems (for debugging)
group :development do
  # enhanced REPL + debugging environment
  gem 'pry'
  gem 'pry-byebug'
  gem 'pry-doc'

  # rubocop, rubocop-rake, and rubocop-rspec are pulled in and version-pinned by
  # voxpupuli-test (via simp-rake-helpers); pinning them here conflicts with its
  # constraints. rubocop-performance is not a voxpupuli-test dependency, so it
  # stays explicit.
  gem 'rubocop-performance', '~> 1.26.0'
end

# Evaluate extra gemfiles if they exist
extra_gemfiles = [
  ENV['EXTRA_GEMFILE'] || '',
  "#{__FILE__}.project",
  "#{__FILE__}.local",
  File.join(Dir.home, '.gemfile')
]
extra_gemfiles.each do |gemfile|
  if File.file?(gemfile) && File.readable?(gemfile)
    eval(File.read(gemfile), binding) # rubocop:disable Security/Eval
  end
end
