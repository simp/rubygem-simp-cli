# frozen_string_literal: true

require 'highline'

# Adds HighLine's color and style methods (e.g. `'text'.red`) to String,
# without replacing core String methods.
#
# HighLine.colorize_strings defines a String method for every HighLine
# style, and the `clear` style replaces the core String#clear. Ruby's
# Net::BufferedIO clears its read buffer with String#clear, so with that
# replacement in place every Net::HTTP response is misread (EOFError). That
# made `simp bootstrap` wait forever for the puppetserver on OpenVox 9's
# Ruby 4.
unless String.method_defined?(:red)
  core_clear = String.instance_method(:clear)
  HighLine.colorize_strings
  String.send(:define_method, :clear, core_clear)
end
