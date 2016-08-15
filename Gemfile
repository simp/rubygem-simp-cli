# Gemfile for bundler (gem install bundler)
#
# To update all gem dependencies:
#
#   bundle
#
# To run a rake task:
#
#   bundle exec rake <task>
#
# NOTE:  This gem needs to run on Ruby 1.8.7 which is native to CentOS/RHEL 6,
# Ruby 1.9.3 which is native to CentOS/RHEL 7, and Ruby 2+ for CentOS/RHEL
# servers on which custom Ruby packages have been installed.  Unfortunately, the
# rspec-based test infrastructure, here, won't work with Ruby 1.8.7.
is_ruby_very_old = Gem::Version.new( RUBY_VERSION ) < Gem::Version.new( '1.9' )
warn( "WARNING: ruby #{RUBY_VERSION} detected!" +
        " Any ruby version below 1.9 will have test issues." ) if is_ruby_very_old

is_ruby_old = Gem::Version.new( RUBY_VERSION ) < Gem::Version.new( '2.0' )

# Allow a comma or space-delimited list of gem servers
if simp_gem_server =  ENV.fetch( 'SIMP_GEM_SERVERS', false )
  simp_gem_server.split( / |,/ ).each{ |gem_server|
    source gem_server
  }
end
source 'https://rubygems.org'

# read dependencies in from the gemspec
gemspec

# mandatory gems
gem 'bundler'
gem 'rake'
gem 'highline', '~> 1.6.1'  # NOTE: For Ruby 1.8.7. 1.7+ requires ruby 1.9.3+
gem 'puppet'
gem 'facter'
gem 'json_pure', (is_ruby_old or is_ruby_very_old) ? '1.5.5' : nil # NOTE: For Ruby 1.8.7 and Ruby 1.9.3

group :testing do
  # bootstrap common environment variables
  gem 'dotenv'

  gem 'travish'

  # Ruby code coverage
  gem 'simplecov', is_ruby_old ? '0.11.2' : nil  # NOTE: For Ruby 1.9.3 (to go with old json/json_pure)

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

  gem 'rubocop', is_ruby_old ? '0.39' : nil # NOTE:  For Ruby 1.9.3
end
