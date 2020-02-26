function kv_test::retrieve_and_persist_binary_key(
  String $key,
  Hash   $simpkv_opts,
  String $outfile
) {

  if simpkv::exists($key, $simpkv_opts) {
    $_result = simpkv::get($key, $simpkv_opts)
    $_value_binary = Binary.new($_result['value'], '%r')

    file { "${outfile}.bin":
      ensure  => present,
      content => $_value_binary
    }

    file { "${outfile}.meta":
      ensure  => present,
      content => to_json_pretty($_result['metadata'])
    }
  } else {
    file { "${outfile}.bin": ensure => absent }
    file { "${outfile}.meta": ensure => absent }
  }
}
