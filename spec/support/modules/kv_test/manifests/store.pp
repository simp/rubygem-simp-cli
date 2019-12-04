class kv_test::store inherits kv_test::params
{
  # add in binary test pair that is distinct for retrieve operations
  $_pairs = $::kv_test::params::key_value_pairs + {
    $::kv_test::params::test_binary_key  => $::kv_test::params::test_binary
    }

  # Add environment and global keys to the default backend
  kv_test::store_keys($_pairs, 'default')

  # Add environment and global keys to the custom backend
  kv_test::store_keys($_pairs, $::kv_test::params::custom_backend)

}
