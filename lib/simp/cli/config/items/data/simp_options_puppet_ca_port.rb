# frozen_string_literal: true

require_relative '../integer_item'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpOptionsPuppetCAPort < IntegerItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super

      @port = if puppet_env_info[:is_pe]
                # We need to keep the port the puppet default if we're using PE
                8140
              else
                8141
              end

      @key         = 'simp_options::puppet::ca_port'
      @description = %{The port on which the Puppet Certificate Authority will listen\n(#{@port} by default).}
    end

    def get_os_value
      Puppet.settings.setting('ca_port').value.to_i
    end

    # x is either the recommended value (Integer) or the query
    # result (String) prior to conversion to Integer
    def validate(x)
      ((x.to_s =~ %r{^\d+$}) ? true : false) && x.to_i.positive? && x.to_i <= 65_535
    end

    def get_recommended_value
      @port
    end
  end
end
