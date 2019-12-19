function kv_test::retrieve_and_persist_key(
  String $key,
  Hash   $libkv_opts,
  String $outfile
) {

  if libkv::exists($key, $libkv_opts) {
    file { $outfile:
      ensure  => present,
      content => to_json_pretty(libkv::get($key, $libkv_opts))
    }
  } else {
    file { $outfile: ensure => absent }
  }
}

