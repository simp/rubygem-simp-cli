require 'fileutils'

module TestUtils
  module LegacyPassgen


    def create_password_files(password_dir, names_with_backup,
        names_without_backup=[])

      FileUtils.mkdir_p(password_dir)

      names_with_backup.each do |name|
        name_file = File.join(password_dir, name)
        File.open(name_file, 'w') do |file|
          file.puts "#{name}_password"
        end

        File.open("#{name_file}.salt", 'w') do |file|
          file.puts "salt for #{name}"
        end

        File.open("#{name_file}.last", 'w') do |file|
          file.puts "#{name}_backup_password"
        end

        File.open("#{name_file}.salt.last", 'w') do |file|
          file.puts "salt for #{name} backup"
        end

      end

      names_without_backup.each do |name|
        name_file = File.join(password_dir, name)
        File.open(name_file, 'w') do |file|
          file.puts "#{name}_password"
        end

        File.open("#{name_file}.salt", 'w') do |file|
          file.puts "salt for #{name}"
        end
      end
    end

    def validate_files(expected_file_info)
      expected_file_info.each do |file,expected_contents|
        if expected_contents.nil?
          expect( File.exist?(file) ).to be false
        else
          expect( File.exist?(file) ).to be true
          expect( IO.read(file).chomp ).to eq expected_contents
        end
      end
    end
  end
end
