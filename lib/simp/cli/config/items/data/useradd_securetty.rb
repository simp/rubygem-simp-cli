require File.expand_path( '../list_item', __dir__ )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::UseraddSecuretty < ListItem
    def initialize
      super
      @key         = 'useradd::securetty'
      @description = %Q{A list of TTYs for which the root user can login.

When useradd::securetty is an empty list, the system will satisfy FISMA
regulations, which require root login via any TTY (including the console)
to be disabled.  For some systems, the inability to login as root via the
console is problematic.  In that case, you may wish to include at least
tty0 to the list of allowed TTYs, despite the security risk.
}
      @allow_empty_list = true
      @warning1 = %Q{IMPORTANT: An empty #{@key} will prevent root login from any TTY.}
      @warning2 = %Q{      >>> This includes logging in from the console <<<}
    end

    def get_recommended_value
      []
    end

    # Warn user about root tty lockout, which is the most secure system
    # behavior, but perhaps unexpected.
    def validate list
      if (list.is_a?(Array) || list.is_a?(String)) && list.empty?
        info( "#{@warning1}\n", [:YELLOW], @warning2, [:YELLOW,:BOLD] )

        # if the value is not pre-assigned, pause to give the user time
        # to think about the impact of not specifying NTP servers
        pause(:info) if @value.nil?
      end
      super
    end

    # Console and tty* are common, and pts/* may be useful for automation
    # https://unix.stackexchange.com/questions/41840/effect-of-entries-in-etc-securetty
    def validate_item( x )
      x =~ /console|^tty\S+|^pts\/[0-9]+/ ? true : false
    end

    def not_valid_message
      "Invalid list of TTYs."
    end
  end
end
