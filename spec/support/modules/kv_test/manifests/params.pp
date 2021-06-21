# This class sets key/value and backend parameters used in the kv_test::store
# and kv_test::retrieve classes.
#
# @param key_info
#   Hash of key information for keys that do not have Binary values
#
#   * Primary key is the name of the simpkv backend.
#     - All backend names except 'default' must exist in simpkv::options in hiera.
#   * Value of each primary key is a Hash with 'keys' and/or 'global_keys' attributes
#   * The 'keys' attribute is a Hash with key/value pairs for the node's Puppet
#     environment.
#   * The 'global_keys' attribute is a Hash with global key/value pairs.
#
# @param binary_key_info
#   Hash of key information for keys that have Binary values
#
#   * Primary key is the name of the simpkv backend.
#     - All backend names except 'default' must exist in simpkv::options in hiera.
#   * Value of each primary key is a Hash with 'keys' and/or 'global_keys' attributes
#   * The 'keys' attribute is a Hash with key/binary-file-ref pairs for the node's
#     Puppet environment.
#   * The 'global_keys' attribute is a Hash with global key/binary-file-ref pairs.
#   * Each 'binary-file-ref' is either a reference to a file within a module
#     (e.g., 'kv_test/test_krb5.keytab') or a fully qualified path to a binary
#     file on the Puppet server.
#
class kv_test::params (
  String[1] $backend1 = 'default',
  String[1] $backend2 = 'custom',

  Hash[String[1],Kv_test::KeyInfo]  $key_info,
  Hash[String[1],Kv_test::KeyInfo]  $binary_key_info
) { }
