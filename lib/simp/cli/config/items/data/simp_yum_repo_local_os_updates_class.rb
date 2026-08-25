# frozen_string_literal: true

require_relative '../class_item'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpYumRepoLocalOsUpdatesClass < ClassItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super
      @key = 'simp::yum::repo::local_os_updates'
    end
  end
end
