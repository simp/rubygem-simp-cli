# frozen_string_literal: true

require 'highline'

# Adds HighLine's color and style methods (e.g. `'text'.red`) to String,
# without replacing core String methods.
#
# HighLine.colorize_strings defines a String method for every HighLine
# style, and its `clear` and `reverse` styles replace the core String#clear
# and String#reverse. Both are restored afterwards. Ruby's
# Net::BufferedIO clears its read buffer with String#clear, so with that
# replacement in place every Net::HTTP response is misread (EOFError). That
# made `simp bootstrap` wait forever for the puppetserver on OpenVox 9's
# Ruby 4.
unless String.method_defined?(:red)
  core_clear = String.instance_method(:clear)
  core_reverse = String.instance_method(:reverse)
  HighLine.colorize_strings
  String.send(:define_method, :clear, core_clear)
  String.send(:define_method, :reverse, core_reverse)
end
