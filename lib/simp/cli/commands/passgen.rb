module Simp::Cli::Commands; end

class Simp::Cli::Commands::Passgen < Simp::Cli
  require 'fileutils'

  @show_list = false
  @show_users = Array.new
  @set_users = Array.new
  @remove_users = Array.new

  @opt_parser = OptionParser.new do |opts|
    opts.banner = "\n=== The SIMP Passgen Tool ==="
    opts.separator ""
    opts.separator "The SIMP Passgen Tool is a simple password control utility. It allows the"
    opts.separator "viewing, setting, and removal of user passwords."
    opts.separator ""
    opts.separator "OPTIONS:\n"

    opts.on("-d", "--dir DIRECTORY", "Where the passgen passwords are stored.") do |dir|
      @target_dir = dir
    end

    opts.on("-l", "--list", "List possible usernames upon which to operate") do
      @show_list = true
    end

    opts.on("-u", "--user USER1[,USER2,USER3]", Array, "Show password(s) for USERNAME") do |name|
      @show_users = name
    end

    opts.on("-s", "--set USER1[,USER2,USER3]", Array, "Set password for USERNAME") do |name|
      @set_users = name
    end

    opts.on("-r", "--remove USER1[,USER2,USER3]", Array, "Remove all passwords for USERNAME") do |name|
      @remove_users = name
    end

    opts.on("-h", "--help", "Print this message.") do
      puts opts
      @help_requested = true
    end

   end

  def self.run(args = Array.new)
    raise "The SIMP Passgen Tool requires at least one argument to work" if args.empty?
    super
    return if @help_requested

    unless @target_dir
      env_path = ::Utils.puppet_info[:environment_path]
      if File.directory?(env_path)
        @target_dir = File.join(env_path, 'simp/simp_autofiles/gen_passwd')
      else
        raise(OptionParser::ParseError, 'Could not find a target passgen directory, please specify one with the `-d` option')
      end
    end

    raise "Target directory '#{@target_dir}' does not exist" unless File.directory?(@target_dir)

    begin
      Dir.chdir(@target_dir) do
          #File.ftype("#{@target_dir}/#{name}").eql?("file")
        @user_names = Dir.glob("*").select do |x|
          File.file?(x) && (x !~ /\..+$/)
        end
      end
    rescue => err
      raise "Error occured while accessing '#{@target_dir}':\n  Causing Error: #{err}"
    end

    if @show_list
      puts "Usernames:\n\t#{@user_names.join("\n\t")}"
      puts
    end

    @show_users.each do |user|
      if @user_names.include?(user)
        Dir.chdir(@target_dir) do
          puts "Username: #{user}"
          current_password = File.open("#{@target_dir}/#{user}", 'r').gets
          puts "  Current:  #{current_password}"
          last_password = nil
          last_password_file = "#{@target_dir}/#{user}.last"
          if File.exists?(last_password_file)
            last_password = File.open(last_password_file, 'r').gets
          end
          puts "  Previous: #{last_password}" if last_password
        end
      else
        raise "Invalid username '#{user}' selected.\n\n Valid: #{@user_names.join(', ')}"
      end
      puts
    end

    @set_users.each do |user|
      password_filename = "#{@target_dir}/#{user}"

      puts "Username: #{user}"
      password = Utils.get_password
      if File.exists?(password_filename)
        if Utils.yes_or_no("Would you like to rotate the old password?", false)
          begin
            FileUtils.mv(password_filename, password_filename + '.last')
          rescue => err
            raise "Error occurred while moving '#{password_filename}' to '#{password_filename + '.last'}'\n  Causing Error: #{err}"
          end
        end
      end
      begin
        File.open(password_filename, 'w') { |file| file.puts password }
      rescue => err
        raise "Error occurred while writing '#{password_filename}'\n  Causing Error: #{err}"
      end
      puts
    end

    @remove_users.each do |user|
      password_filename = "#{@target_dir}/#{user}"

      if File.exists?(password_filename)
        if Utils.yes_or_no("Are you sure you want to remove all entries for #{user}?", false)
          show_password(user)

          last_password_filename = password_filename + '.last'
          if File.exists?(last_password_filename)
            File.delete(last_password_filename)
            puts "#{last_password_filename} deleted"
          end

          File.delete(password_filename)
          puts "#{password_filename} deleted"
        end
      end
      puts
    end
  end

  # Resets options to original values.
  # This ugly method is needed for unit-testing, in which multiple occurrences of
  # the self.run method are called with different options.
  # FIXME Variables set here are really class variables, not instance variables.
  def self.reset_options
    @show_list = false
    @show_users = Array.new
    @set_users = Array.new
    @remove_users = Array.new
    @target_dir = nil
    @help_requested = false
  end
end
