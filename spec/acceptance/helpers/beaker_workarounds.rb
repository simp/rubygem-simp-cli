module Acceptance
  module Helpers
    module BeakerWorkarounds

      # Temporary, partial, hack until we have a good solution to beaker's ssh
      # connection logic problems (as of beaker 4.11.0). That logic treats ssh
      # connection timeouts from long running actions as failures...without any
      # mechanism to configure just the connection timeout longer.
      #
      # All this method provides is a mechanism to work around a ssh connection
      # failure *before* you run a command. So, place it in parts of the code
      # where you have long running segments happening. It doesn't help if
      # the ssh connection failure happens in the **middle** of a long-running
      # segment.
      def ensure_ssh_connection(host, reconnect_attempts = 3)
        tries = reconnect_attempts
        begin
          on(host, 'uptime')
        rescue Beaker::Host::CommandFailure => e
          if e.message.include?('connection failure') && (tries > 0)
            puts "Retrying due to << #{e.message.strip} >>"
            tries -= 1
            retry
          else
            raise e
          end
        end
      end

    end
  end
end

