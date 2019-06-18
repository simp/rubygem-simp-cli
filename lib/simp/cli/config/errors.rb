module Simp; end
class Simp::Cli; end
module Simp::Cli::Config

  # Exception class for errors during ActionItem::safe_apply()
  # and ActionItem::apply()
  class ApplyError < StandardError; end

  # Exception class for errors the indicate internal, software error, for
  # example errors in which the Item tree is ordered incorrectly.
  class InternalError < StandardError
    def initialize(message)
      super("Internal error: #{message}")
    end
  end

  class MissingItemError < InternalError;
    def initialize(missing_item_key, class_needing_item)
      super("#{class_needing_item} could not find #{missing_item_key}")
    end
  end

  class ValidationError < StandardError; end

end
