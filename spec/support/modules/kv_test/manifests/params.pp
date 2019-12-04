# This class sets key/value parameters used in kv_test manifests.
class kv_test::params (
  String         $test_bool_key           = "boolean",
  String         $test_integer_key        = "integer",
  String         $test_float_key          = "float",
  String         $test_string_key         = "string",
  String         $test_array_strings_key  = "complex/array_strings",
  String         $test_array_integers_key = "complex/array_integers",
  String         $test_hash_key           = "complex/hash",

  Boolean        $test_bool               = true,
  Integer        $test_integer            = 123,
  Float          $test_float              = 4.567,
  String         $test_string             = 'string1',
  Array          $test_array_strings      = ['string2', 'string3' ],
  Array[Integer] $test_array_integers     = [ 8, 9, 10],
  Hash           $test_hash               = { 'key1' => 'string4', 'key2' => 11,
    'key3' => false, 'key4' => { 'nkey1' => 'string5', 'nkey2' => true, 'nkey3' => 12 } },

  Hash           $key_value_pairs         = { $test_bool_key           => $test_bool,
                                              $test_integer_key        => $test_integer,
                                              $test_float_key          => $test_float,
                                              $test_string_key         => $test_string,
                                              $test_array_strings_key  => $test_array_strings,
                                              $test_array_integers_key => $test_array_integers,
                                              $test_hash_key           => $test_hash },

  # binary key/value pair handled separately because special logic required for retrieve
  String         $test_binary_key         = "complex/binary",
  Binary         $test_binary             = binary_file('kv_test/test_krb5.keytab'),

  String         $custom_backend          = 'custom'
) { }
