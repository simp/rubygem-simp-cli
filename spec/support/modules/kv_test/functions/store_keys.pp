function kv_test::store_keys(
  Hash   $key_value_pairs,
  String $backend
) {

  $_env_opts = {
    'environment' => $::environment,
    'backend'     => $backend
  }

  $_global_opts = {
    'environment' => '',
    'backend'     => $backend
  }

  $key_value_pairs.each |$key, $value| {
    libkv::put($key, $value, { 'id' => "${backend} ${::environment} ${key}" }, $_env_opts)
    libkv::put("global_${key}", $value, { 'id' => "${backend} global global_${key}" }, $_global_opts)
  }
}

