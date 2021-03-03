require_relative '../action_item'
require_relative '../data/cli_local_priv_user'
require_relative '../data/cli_local_priv_user_password'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CreateLocalUserAction < ActionItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key               = 'cli::create_local_user'
      @description       = 'Create a privileged local user'
      @die_on_apply_fail = true
      @username          = nil
      @category          = :system
    end

    def apply
      @applied_status = :failed
      @username = get_item( 'cli::local_priv_user' ).value
      pwd_hash = get_item( 'cli::local_priv_user_password' ).value

      result = create_resource('group', @username)

      if result
        user_attributes = [
          "groups='#{@username}'",
          "password='#{pwd_hash}'",
          "home=/var/local/#{@username}",
          'manageHome=true',
          'shell=/bin/bash'
        ]

        result = create_resource('user', @username, user_attributes)
      end

      @applied_status = :succeeded if result
    end

    def apply_summary
      "Creation of local user#{@username ? " #{@username}" : ''} #{@applied_status}"
    end

    # Create a resource using `puppet resource`
    #
    # @param type Resource type
    # @param name Resource name
    # @param attributes Additional resource attributes beyond 'ensure=present'
    #
    # @return whether resource was created
    #
    def create_resource(type, name, attributes=[])
      result = Simp::Cli::Utils::show_wait_spinner {
        # puppet command won't necessarily exit with a non-0 exit code upon
        # failure, but will definitely return the status of the resource on
        # success
        cmd_succeeded = true
        cmd = "puppet resource #{type} #{name} ensure=present #{attributes.join(' ')} --to_yaml"
        result = run_command(cmd)
        if result[:stdout].match(/ensure:\s+present/)
          info("Created #{type} '#{name}'")
        else
          err_msg = "Unable to create #{type} '#{name}'"
          # if command failed but returned 0, error messages not already logged
          err_msg += ":\n#{result[:stderr]}" if result[:status]
          error(err_msg)
          cmd_succeeded = false
        end
        cmd_succeeded
      }

      result
    end
  end
end
