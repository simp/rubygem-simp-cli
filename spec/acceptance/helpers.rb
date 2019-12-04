rb_files = File.expand_path( 'helpers/**/*.rb', __dir__)
Dir.glob( rb_files ).sort_by(&:to_s).each { |file| require file }
