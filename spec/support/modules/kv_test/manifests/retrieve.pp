class kv_test::retrieve(
  String          $test_dir          = '/var/kv_test',
  #FIXME need mechanism to create any sub-dirs from extra keys
  Optional[Array] $extra_keys        = undef,
  Optional[Array] $extra_binary_keys = undef
) inherits kv_test::params {

  $_dirs = [
    $test_dir,
    "${test_dir}/default/",
    "${test_dir}/default/global_complex",
    "${test_dir}/default/${::environment}",
    "${test_dir}/default/${::environment}/complex",
    "${test_dir}/${::kv_test::params::custom_backend}",
    "${test_dir}/${::kv_test::params::custom_backend}/global_complex",
    "${test_dir}/${::kv_test::params::custom_backend}/${::environment}",
    "${test_dir}/${::kv_test::params::custom_backend}/${::environment}/complex",
  ]

  file { $_dirs:
    ensure => directory
  }

  $_reg_keys = $::kv_test::params::key_value_pairs.keys
  $_bin_keys = [ $::kv_test::params::test_binary_key ]

  kv_test::retrieve_and_persist_keys($_reg_keys, $_bin_keys, 'default', $test_dir)
  kv_test::retrieve_and_persist_keys($_reg_keys, $_bin_keys, $::kv_test::params::custom_backend, $test_dir)

  if $extra_keys {
    kv_test::retrieve_and_persist_keys($extra_keys, [], 'default', $test_dir)
    kv_test::retrieve_and_persist_keys($extra_keys, [], $::kv_test::params::custom_backend, $test_dir)
  }

  if $extra_binary_keys {
    kv_test::retrieve_and_persist_keys([], $extra_binary_keys, 'default', $test_dir)
    kv_test::retrieve_and_persist_keys([], $extra_binary_keys, $::kv_test::params::custom_backend, $test_dir)
  }
}
