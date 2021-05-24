gem_sources = ENV.fetch('GEM_SERVERS','https://rubygems.org').split(/[, ]+/)

gem_sources.each { |gem_source| source gem_source }

# read dependencies in from the gemspec
gemspec

# mandatory gems
gem 'bundler'
gem 'facter'
gem 'highline', :path => 'ext/gems/highline'
gem 'puppet', ENV.fetch('PUPPET_VERSION',  '~>6')
gem 'rake', '>= 12.3.3'
gem 'simp-rake-helpers', ENV.fetch('SIMP_RAKE_HELPERS_VERSION', ['>= 5.6', '< 6.0'])

gem 'simp-beaker-helpers', ENV['SIMP_BEAKER_HELPERS_VERSION'] || ['>= 1.22.1', '< 2']
gem 'r10k', ENV.fetch('R10k_VERSION',  '~>3')

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
  gem 'rubocop-rspec'
end
