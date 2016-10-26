# ------------------------------------------------------------------------------
# NOTE:  This gem needs to run on Ruby 1.8.7 which is native to CentOS/RHEL 6,
#        Ruby 2.0.0 which is native to CentOS/RHEL 7. Unfortunately, the
#        rspec-based test infrastructure that this Gemfile supports requires a
#        minimum of Ruby 2.0.0.
# ------------------------------------------------------------------------------
gem_sources   = ENV.key?('SIMP_GEM_SERVERS') ? ENV['SIMP_GEM_SERVERS'].split(/[, ]+/) : ['https://rubygems.org']
gem_sources.each { |gem_source| source gem_source }

ruby_is_old = Gem::Version.new( RUBY_VERSION ) < Gem::Version.new( '2.0' )
warn( "WARNING: ruby #{RUBY_VERSION} detected!" +
        " The rake tasks this Gemfile supports are likely to fail with any version of Ruby under 2.0." ) if ruby_is_old
# read dependencies in from the gemspec
gemspec

# mandatory gems
gem 'bundler'
gem 'rake'
gem 'highline', '~> 1.6.1'  # NOTE: This is the latest Ruby 1.8.7 can use.
gem 'puppet', ENV.fetch('PUPPET_VERSION',  '~>3')
gem 'facter'
gem 'json_pure', ruby_is_old ? '1.5.5' : '~> 1.8.0'

group :testing do
  # bootstrap common environment variables
  gem 'dotenv'

  gem 'travish'

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
  gem 'pry-doc'

  # Automatically test changes
  gem 'guard'
  gem 'guard-shell'
  gem 'guard-rspec'

  # Generate HISTORY.md from git tags (experimental, but promising)
  gem 'gitlog-md'

  gem 'rubocop'
end
