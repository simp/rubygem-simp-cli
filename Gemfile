# frozen_string_literal: true

gem_sources = ENV.fetch('GEM_SERVERS', 'https://rubygems.org').split(%r{[, ]+})

gem_sources.each { |gem_source| source gem_source }

# read dependencies in from the gemspec
gemspec

# mandatory gems
gem 'bundler'
gem 'facter'
gem 'highline', :path => 'ext/gems/highline'
# renovate: datasource=rubygems versioning=ruby
gem 'puppet', ENV.fetch('PUPPET_VERSION', ['>= 7', '< 9'])
# renovate: datasource=rubygems versioning=ruby
gem 'simp-rake-helpers', ENV['SIMP_RAKE_HELPERS_VERSION'] || ['~> 5.24.0', '< 6']

# renovate: datasource=rubygems versioning=ruby
gem 'r10k', ENV.fetch('R10k_VERSION', '~> 4')
# renovate: datasource=rubygems versioning=ruby
gem 'simp-beaker-helpers', ENV['SIMP_BEAKER_HELPERS_VERSION'] || ['>= 1.28.0', '< 2']

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

  gem 'rubocop'
  gem 'rubocop-performance'
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
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
