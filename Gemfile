# ------------------------------------------------------------------------------
# NOTE: SIMP Puppet rake tasks support ruby 2.1.9
# ------------------------------------------------------------------------------
gem_sources = ENV.fetch('GEM_SERVERS','https://rubygems.org').split(/[, ]+/)

gem_sources.each { |gem_source| source gem_source }

# read dependencies in from the gemspec
gemspec

# mandatory gems
gem 'bundler'
gem 'facter'
gem 'highline', :path => 'ext/gems/highline'
gem 'puppet', ENV.fetch('PUPPET_VERSION',  '~>4')
gem 'rake'
gem 'simp-rake-helpers', ENV.fetch('SIMP_RAKE_HELPERS_VERSION', ['>= 5.2.0', '<= 6.0.0'])

group :testing do
  # bootstrap common environment variables
  gem 'dotenv'

  gem 'travish'
  gem 'travis-lint'

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
  gem 'pry-byebug', '~> 3.4.2'
  gem 'pry-doc'

  # Automatically test changes
  gem 'guard'
  gem 'guard-shell'
  gem 'guard-rspec'

  # `listen` is a dependency of `guard`
  # from `listen` 3.1+, `ruby_dep` requires Ruby version >= 2.2.3, ~> 2.2
  gem 'listen', '~> 3.0.6'

  # Generate HISTORY.md from git tags (experimental, but promising)
  gem 'gitlog-md'

  gem 'rubocop', '>= 0.49'
end
