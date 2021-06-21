# Retrieves keys with Binary values from a backend (key/value store) and writes
# the information for each to its a pair of files
#
# * 1 file contains the binary data
# * 1 file contains the metadata.
# * Separate files allow easy comparison with original binary files
#
# @param keys
#   Keys that have Binary values
#
# @param backend
#   Name of the backend from which to retrieve the keys

# @param root_dir
#   Root directory of output key files that will be written

function kv_test::retrieve_and_persist_binary_keys(
  Kv_test::KeyList $keys,
  String           $backend,
  String           $root_dir
) {

  $_env_simpkv_opts = { 'backend' => $backend }
  $_global_simpkv_opts = {
    'global'  => true,
    'backend' => $backend
  }

  $keys['keys'].each |$key| {
    $_env_filename = "${root_dir}/${backend}/environments/${::environment}/${key}"
    kv_test::retrieve_and_persist_binary_key($key, $_env_simpkv_opts, $_env_filename)
  }

  $keys['global_keys'].each |$key| {
    $_global_filename = "${root_dir}/${backend}/globals/${key}"
    kv_test::retrieve_and_persist_binary_key($key, $_global_simpkv_opts, $_global_filename)
  }
}

