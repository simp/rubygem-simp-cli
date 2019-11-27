class passgen_test(
  String $test_dir            = '/var/passgen_test',
  Hash   $keys                = {
    'passgen_test_default' =>
      {}, # <==> complexity=0, complex_only=false, length=32
    'passgen_test_c0_8'    =>
      {'complexity' => 0, 'complex_only' => false, 'length' => 8},
    'passgen_test_c1_1024' =>
      {'complexity' => 1, 'complex_only' => false, 'length' => 1024},
    'passgen_test_c2_20'   =>
      {'complexity' => 2, 'complex_only' => false, 'length' => 20},
    'passgen_test_c2_only' =>
      {'complexity' => 2, 'complex_only' => true,  'length' => 32}
  },
  Array $folders              = [ 'app1', 'app2', 'app3'],
  Optional[Array] $extra_keys = undef
) {

  file { $test_dir:
    ensure => directory
  }

  $keys.each |String $name, Hash $settings| {
    file { "${test_dir}/${::environment}-${name}":
      ensure  => present,
      content => simplib::passgen($name, $settings)
    }
  }

  $_use_libkv = simplib::lookup('simplib::passgen::libkv', { 'default_value' => false })
  if $_use_libkv {
    $folders.each |String $folder| {
      file { "${test_dir}/${::environment}-${folder}":
        ensure => directory
      }

      $keys.each |String $name, Hash $settings| {
        file { "${test_dir}/${::environment}-${folder}/sub_${name}":
           ensure  => present,
           content => simplib::passgen("${folder}/sub_${name}", $settings)
        }
      }
    }
  }

  if $extra_keys {
    $extra_keys.each |String $name| {
      file { "${test_dir}/${::environment}-${name}":
        ensure  => present,
        content => simplib::passgen($name)
      }
    }
  }
}
