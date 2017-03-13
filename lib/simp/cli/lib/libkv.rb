# vim: set expandtab ts=2 sw=2:
module Simp; end
require_relative 'utils.rb'
require 'pry'
class Simp::Libkv
  def initialize(url = nil)
    if (url == nil)
    # XXX Todo: Get url from puppet lookup
    end
    @url = url
    @auth = {}
    @libkv_code, @loader_filename = ::Utils.load_code_from_puppet("libkv", ["puppet_x/libkv/libkv.rb"])
  end
  def method_missing(symbol, *args, &block)
    @libkv_code.send(symbol, @url, @auth, *args, &block)
  end
end
