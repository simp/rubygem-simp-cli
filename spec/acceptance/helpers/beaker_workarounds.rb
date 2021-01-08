module Acceptance
  module Helpers
    module BeakerWorkarounds

      # Temporary, partial, hack until we have a good solution to beaker's ssh
      # connection logic problems that started with the commit of
      # https://github.com/voxpupuli/beaker/pull/1586. The 'improved' beaker
      # logic in lib/beaker/ssh_connection.rb treats ssh connection timeouts that
      # can happen on a host when long running actions are happening on other nodes
      # as failures on the disconnected host. Previously, it would attempt to
      # reconnect to perform the action requested on the host and, upon success,
      # move on.
      #
      # All this method provides is a mechanism to work around a ssh connection
      # failure *before* you run a command. So, place it in parts of the code
      # where you have long running segments happening. It doesn't help if
      # the ssh connection failure happens in the **middle** of a long-running
      # segment.
      #
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

