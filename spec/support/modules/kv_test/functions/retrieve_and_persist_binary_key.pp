function kv_test::retrieve_and_persist_binary_key(
  String $key,
  Hash   $libkv_opts,
  String $outfile
) {

  if libkv::exists($key, $libkv_opts) {
    $_result = libkv::get($key, $libkv_opts)
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
