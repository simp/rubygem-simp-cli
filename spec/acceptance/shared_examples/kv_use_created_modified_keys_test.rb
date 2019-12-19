# Test environment and global keys created/modified by 'kv put' operation can be
# used by a manifest in a 'puppet agent' run.
#
# The kv_test::retrieve manifest retrieves the keys and then stores them
# in files in out_root_path.
#
# @param host Host object on which to execute test
# @param env Puppet environment
#
# Assumes the following are in scope:
#   updated_list_env    = New list result (Hash) for / and complex/ folders
#                         for env in backend under test
#   updated_list_global = New list result (Hash) for global / and global_complex/
#                         for env in backend under test
#   created_key_names   = Hash of key info for non-binary created keys
#   created_binary_key_names = Hash of key info for created binary keys
#   out_root_path       = Root path to files persisted by kv_test::retrieve
#                         containing key info for the backend under test
require 'json'
shared_examples 'kv use created/modified keys test' do |host, env|
  include_examples 'configure puppet env', host, env

  it 'should ensure class list only has test class to retrieve key info' do
    default_yaml_file = File.join( '/etc/puppetlabs/code/environments', env,
      'data', 'default.yaml')

    hieradata = YAML.load( on(host, "cat #{default_yaml_file}").stdout )
    hieradata['classes'] = [ 'kv_test::retrieve' ]
    create_remote_file(host, default_yaml_file, hieradata.to_yaml)
    on(host, "cat #{default_yaml_file}")
  end

  it 'should add any created keys to list of keys to retrieve' do
    if created_key_names.empty? && created_binary_key_names.empty?
      puts '>>> No created keys <<<'
    else
      default_yaml_file = File.join( '/etc/puppetlabs/code/environments', env,
        'data', 'default.yaml')

      hieradata = YAML.load( on(host, "cat #{default_yaml_file}").stdout )
      unless created_key_names.empty?
        hieradata['kv_test::retrieve::extra_keys'] = created_key_names
      end

      unless created_binary_key_names.empty?
        hieradata['kv_test::retrieve::extra_binary_keys'] = created_binary_key_names
      end

      create_remote_file(host, default_yaml_file, hieradata.to_yaml)
      on(host, "cat #{default_yaml_file}")
    end
  end

  it 'should apply manifest to retrieve and use created/modified values' do
    retry_on(host, 'puppet agent -t', :desired_exit_codes => [0],
      :max_retries => 5, :verbose => true.to_s)
  end

  it 'should have retrieved correct values for environment keys' do
    keys = keys_info('/', updated_list_env)
    keys.merge!( keys_info('complex', updated_list_env) )
    root_path = File.join(out_root_path, env)
    verify_files(host, keys, root_path)
  end

  it 'should have retrieved correct values for global keys' do
    keys = keys_info('/', updated_list_global)
    keys.merge!( keys_info('global_complex', updated_list_global) )
    verify_files(host, keys, out_root_path)
  end
end
