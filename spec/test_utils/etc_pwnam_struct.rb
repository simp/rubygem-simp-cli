# frozen_string_literal: true

module TestUtils
  require 'ostruct'

  EtcPwnamStruct = Struct.new(:name, :passwd, :uid, :gid, :gecos, :dir, :shell)
end
