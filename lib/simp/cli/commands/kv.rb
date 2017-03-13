# vim: set expandtab ts=2 sw=2:
require File.expand_path( '../../cli', File.dirname(__FILE__) )

module Simp::Cli::Commands; end
class Simp::Cli::Commands::KV < Simp::Cli

  @url = "mock:///"

  @opt_parser = OptionParser.new do |opts|
    opts.banner = "\nSIMP KV Tool"
    opts.separator ""
    opts.separator "The SIMP KV Tool provides an api for accessing the libkv backend in a puppet environment."
    opts.separator ""
    opts.separator "OPTIONS:\n"

    opts.on("-x", "--url URL", "Libkv url to use") do |url|
      @url = url
    end
   end
  def self.run(args = Array.new)
    super
    subcommand = args.shift
    if (subcommand == nil)

    else
      libkv = Simp::Libkv.new(@url)
      case subcommand
      when "create"
        params = {}
        params["key"] = args.shift
        params["value"] = args.shift
        puts libkv.atomic_create(params)
      when "put"
        params = {}
        params["key"] = args.shift
        params["value"] = args.shift
        puts libkv.put(params)
      when "get"
        params = {}
        params["key"] = args.shift
        puts libkv.get(params)
      when "delete"
        params = {}
        params["key"] = args.shift
        puts libkv.delete(params)
      when "list"
        params = {}
        params["key"] = args.shift
        puts libkv.list(params)
      end
    end
  end

  # Resets options to original values.
  # This ugly method is needed for unit-testing, in which multiple occurrences of
  # the self.run method are called with different options.
  # FIXME Variables set here are really class variables, not instance variables.
  def self.reset_options
  end
end
