$: << File.expand_path( '../lib/', __FILE__ )

require 'fileutils'
require 'find'
require 'rake/clean'
require 'rspec/core/rake_task'
require 'rubygems'
require 'simp/rake'

Simp::Rake::Pkg.new(File.dirname(__FILE__))

@package='simp-cli'
@rakefile_dir=File.dirname(__FILE__)


CLEAN.include "#{@package}-*.gem"
CLEAN.include 'coverage'
CLEAN.include 'dist'
CLEAN.include 'pkg'
Find.find( @rakefile_dir ) do |path|
  if File.directory? path
    CLEAN.include path if File.basename(path) == 'tmp'
  else
    Find.prune
  end
end


desc 'Ensure gemspec-safe permissions on all files'
task :chmod do
  gemspec = File.expand_path( "#{@package}.gemspec", @rakefile_dir ).strip
  spec = Gem::Specification::load( gemspec )
  spec.files.each do |file|
    FileUtils.chmod 'go=r', file
  end
end

desc 'special notes about these rake commands'
task :help do
  puts %Q{
== Environment Variables ==
SIMP_RPM_BUILD     when set, alters the gem produced by pkg:gem to be RPM-safe.
                   'pkg:gem' sets this automatically.
== Restrictions ==
- Because the code for this gem uses a global, singleton HighLine object,
  the tests for this code cannot be parallelized.
- To prevent actual changes from being made to your system, some of the
  'simp config' tests fail if the tests are run as root.
  }
end

desc "Run spec tests"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ['--color']
  t.pattern = 'spec/**/*_spec.rb'
end

namespace :pkg do
  @specfile_template = "rubygem-#{@package}.spec.template"
  @specfile          = "build/rubygem-#{@package}.spec"

  # ----------------------------------------
  # DO NOT UNCOMMENT THIS: the spec file requires a lot of tweaking
  # ----------------------------------------
  #  desc "generate RPM spec file for #{@package}"
  #  task :spec => [:clean, :gem] do
  #    Dir.glob("pkg/#{@package}*.gem") do |pkg|
  #      sh %Q{gem2rpm -t "#{@specfile_template}" "#{pkg}" > "#{@specfile}"}
  #    end
  #  end

  desc "build rubygem package for #{@package}"
  task :gem => :chmod do
    Dir.chdir @rakefile_dir
    Dir['*.gemspec'].each do |spec_file|
      cmd = %Q{SIMP_RPM_BUILD=1 bundle exec gem build "#{spec_file}" &> /dev/null}
      sh cmd
      FileUtils.mkdir_p 'dist'
      FileUtils.mv Dir.glob("#{@package}*.gem"), 'dist/'
    end
  end


  desc "build and install rubygem package for #{@package}"
  task :install_gem => [:clean, :gem] do
    Dir.chdir @rakefile_dir
    Dir.glob("dist/#{@package}*.gem") do |pkg|
      sh %Q{bundle exec gem install #{pkg}}
    end
  end

  task :rpm => [:gem]
end
# vim: syntax=ruby
