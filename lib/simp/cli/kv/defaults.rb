module Simp; end
class Simp::Cli; end
module Simp::Cli::Kv

  DEFAULT_PUPPET_ENVIRONMENT = 'production'
  DEFAULT_LIBKV_BACKEND      = 'default'
  DEFAULT_GLOBAL_KEY         = false
  DEFAULT_FORCE              = false # do not prompt user to confirm operation

  KEY_INFO_HELP = <<~KEY_INFO_FORMAT
    KEY INFO FORMAT
    The complete information for an individual key whose value is not a binary
    string is represented as a Hash with two required attributes:
    * 'value':
      - A simple value (UTF-8 string, Boolean, or number)
      - Hash, Array, or nested Hash/Array structure whose terminal nodes are
        simple values
    * 'metadata': Hash whose contents can be Hashes, Arrays, or nested Hashes/Arrays
      structures of simple values.

    The complete information for an individual key whose value is a binary
    string is represented as a Hash with four required attributes:
    * 'value': Base64 (strict) encoded string
    * 'metadata': Hash whose contents can be Hashes, Arrays, or nested Hashes/Arrays
    * 'encoding': Always set to 'base64'
    * 'original_encoding': Always set to 'ASCII-8BIT'

    The key information is stored in the key/value store as a JSON representation
    of the Hash.  For example,

      {"value":2.3849,"metadata":{"foo":{"bar":"baz"}}}

      {"value":BQIAAABXAAIABFQ=","metadata":{},"encoding":"base64",
       "original_encoding":"ASCII-8BIT"}
  KEY_INFO_FORMAT
end
