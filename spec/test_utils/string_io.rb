module TestUtils
  # This class provides extensions to the StringIO class so that it can
  # simulate STDIN and STDOUT in HighLine in unit tests.
  #
  # * Based on HighLine::IOConsoleCompatible used in HighLine unit tests.
  # * It is only needed for a query in which the echo value is set (e.g.,
  #   PasswordItem).
  #
  class StringIO < ::StringIO

    def getch
      getc
    end

    attr_accessor :echo

    def winsize
      [24, 80]
    end

  end
end
