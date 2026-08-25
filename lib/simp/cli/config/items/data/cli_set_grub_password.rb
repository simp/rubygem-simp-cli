# frozen_string_literal: true

require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::CliSetGrubPassword < YesNoItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super
      @key         = 'cli::set_grub_password'
      @description = %(Whether to set the GRUB password on this system.)
      @data_type   = :cli_params
    end

    def get_recommended_value
      os_value || 'yes'
    end
  end
end
