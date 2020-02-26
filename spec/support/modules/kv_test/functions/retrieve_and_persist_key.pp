function kv_test::retrieve_and_persist_key(
  String $key,
  Hash   $simpkv_opts,
  String $outfile
) {

  if simpkv::exists($key, $simpkv_opts) {
    file { $outfile:
      ensure  => present,
      content => to_json_pretty(simpkv::get($key, $simpkv_opts))
    }
  } else {
    file { $outfile: ensure => absent }
  }
}

