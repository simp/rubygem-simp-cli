# Retrieves keys from the 'default' and custom backend and persists
# the key info to files for evaluation
#
# * Standard set of test keys to retrieve are specified by
#   $kv_test::params::key_info and $kv_test::params::binary_key_info
# * Additional keys persisted in the backends can be specified by
#   $extra_key_list and/or $extra_binary_key_list.
#
# @param test_out_dir
#   Root directory of output key files
#
# @param extra_key_list
#   Other keys with non-Binary values stored in the backends
#   * Key storage was done outside of this module.
#   * Primary key is the name of the simpkv backend.
#     - All backend names except 'default' must exist in simpkv::options in hiera.
#   * Value of each primary key is a Hash with 'keys' and/or 'global_keys' attributes
#   * The 'keys' attribute is an Array of key names for the node's Puppet environment.
#   * The 'global_keys' attribute is a Array of global key names.
#
# @param extra_binary_key_list
#   Other keys with Binary values that are stored in the backends
#   * Key storage was done outside of this module.
#   * Primary key is the name of the simpkv backend.
#     - All backend names except 'default' must exist in simpkv::options in hiera.
#   * Value of each primary key is a Hash with 'keys' and/or 'global_keys' attributes
#   * The 'keys' attribute is an Array of key names for the node's Puppet environment.
#   * The 'global_keys' attribute is a Array of global key names.
#
class kv_test::retrieve(
  String                                      $test_out_dir          = '/var/kv_test_out',
  Optional[Hash[String[1],Kv_test::KeyList]]  $extra_key_list        = undef,
  Optional[Hash[String[1],Kv_test::KeyList]]  $extra_binary_key_list = undef
) inherits kv_test::params {

  $kv_test::params::key_info.each |String $backend, Kv_test::KeyInfo $key_info| {
    $_reg_keys_hash = kv_test::keyinfo_to_keylist($key_info)
    kv_test::retrieve_and_persist_keys($_reg_keys_hash, $backend, $test_out_dir)
  }

  $kv_test::params::binary_key_info.each |String $backend, Kv_test::KeyInfo $key_info| {
    $_bin_keys_hash = kv_test::keyinfo_to_keylist($key_info)
    kv_test::retrieve_and_persist_binary_keys($_bin_keys_hash, $backend, $test_out_dir)
  }

  if $extra_key_list {
    $extra_key_list.each |String $backend, Kv_test::KeyList $key_list| {
      kv_test::retrieve_and_persist_keys($key_list, $backend, $test_out_dir)
    }
  }

  if $extra_binary_key_list {
    $extra_binary_key_list.each |String $backend, Kv_test::KeyList $key_list| {
      kv_test::retrieve_and_persist_binary_keys($key_list, $backend, $test_out_dir)
    }
  }
}
