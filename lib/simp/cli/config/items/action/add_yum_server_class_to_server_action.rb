require_relative '../add_server_class_action_item'

module Simp::Cli::Config
  class Item::AddYumServerClassToServerAction < AddServerClassActionItem

    def initialize
      @class_to_add = 'simp::server::yum'  # pre-define, so description is set
      super
      @key          = 'puppet::add_yum_server_class_to_server'
    end
  end
end
