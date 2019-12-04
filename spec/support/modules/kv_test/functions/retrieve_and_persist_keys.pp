function kv_test::retrieve_and_persist_keys(
  Array  $regular_keys,
  Array  $binary_keys,
  String $backend,
  String $root_dir
) {

  $_env_opts = {
    'environment' => $::environment,
    'backend'     => $backend
  }

  $_global_opts = {
    'environment' => '',
    'backend'     => $backend
  }

  $regular_keys.each |$key| {
    $_env_filename = "${root_dir}/${backend}/${::environment}/${key}"
    kv_test::retrieve_and_persist_key($key, $_env_opts, $_env_filename)

    $_global_filename = "${root_dir}/${backend}/global_${key}"
    kv_test::retrieve_and_persist_key("global_${key}", $_global_opts, $_global_filename)
  }

  $binary_keys.each |$key| {
    $_env_filename = "${root_dir}/${backend}/${::environment}/${key}"
    kv_test::retrieve_and_persist_binary_key($key, $_env_opts, $_env_filename)

    $_global_filename = "${root_dir}/${backend}/global_${key}"
    kv_test::retrieve_and_persist_binary_key("global_${key}", $_global_opts, $_global_filename)
  }
}

