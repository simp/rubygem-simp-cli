# Transforms a Kv_test::KeyInfo into a Kv_test::KeyList
#
# @param key_info
#   Hash containing detailed information about global and Puppet environment keys
# @return [Kv_test::KeyList]
#   Hash containing abbreviated information about global and Puppet environment
#   keys
#
function kv_test::keyinfo_to_keylist(
  Kv_test::KeyInfo $key_info
) {

  {
    'keys'        => ('keys' in $key_info) ? {
      true    => $key_info['keys'].keys,
      default => []
    },
    'global_keys' => ('global_keys' in $key_info) ? {
      true    => $key_info['global_keys'].keys,
      default => []
    }
  }
}

