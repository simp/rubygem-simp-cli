# Stores keys in a backend (key/value store)
# @param key_info
#   Hash containing information about global and Puppet environment keys to
#    be stored
function kv_test::store_keys(
  Kv_test::KeyInfo $key_info,
  String[1]        $backend
) {

  if 'keys' in $key_info {
    $_env_simpkv_opts = { 'backend' => $backend }
    $key_info['keys'].each |$key, $value| {
      simpkv::put($key, $value, { 'id' => "${backend} ${::environment} ${key}" }, $_env_simpkv_opts)
    }
  }

  if 'global_keys' in $key_info {
    $_global_simpkv_opts = {
      'global'  => true,
      'backend' => $backend
    }

    $key_info['global_keys'].each |$key, $value| {
      simpkv::put($key, $value, { 'id' => "${backend} global ${key}" }, $_global_simpkv_opts)
    }
  }
}
