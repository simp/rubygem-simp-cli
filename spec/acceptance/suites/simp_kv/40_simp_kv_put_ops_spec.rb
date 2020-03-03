require 'spec_helper_acceptance'
require 'deep_merge'
require 'json'

test_name 'simp kv put operations'

describe 'simp kv put operations' do
  let(:infile) { '/root/put.json' }
  let(:outfile) { '/root/list.json' }

  # In the test set up, production and dev Puppet envs both share the same
  # simpkv backends (default and custom).  So, to cleanly test key modifications
  # and additions in each environment, this test will apply changes to the
  # default backend via the production env, only, and apply changes to the
  # custom backend via the dev environment, only.
  #
  [ [ 'production', 'default', ''                 ],
    [ 'dev',        'custom',  '--backend custom' ]
  ].each do |env, backend, backend_opt|
    hosts.each do |host|
      context "modifying keys for #{env} env #{backend} backend on #{host}" do
        let(:created_key_names) { [] }
        let(:created_binary_key_names) { [] }
        let(:updated_list_env) {
          change_key_info(detailed_kv_list_results("#{backend} #{env}", false))
        }

        let(:updated_list_global) {
          change_key_info(detailed_kv_list_results("#{backend} global", true))
        }

        let(:out_root_path) { "/var/kv_test/#{backend}" }

        include_examples 'kv put modify operation test', host, env, backend_opt
        include_examples 'kv use created/modified keys test', host, env
      end

      context "creating keys for #{env} env #{backend} backend on #{host}" do
        let(:created_key_names) { [ 'new1', 'new2' ] }
        let(:created_binary_key_names) {
          # will be prefixed with 'global_' for global keys
          [ 'complex/bin_new1', 'complex/bin_new2' ]
        }
        let(:created_keys_env) {
          extra_keys, extra_list = create_key_info(created_key_names,
            created_binary_key_names, env, backend)
          extra_keys
        }

        let(:created_keys_global) {
          extra_keys, extra_list = create_key_info(created_key_names,
            created_binary_key_names, nil, backend)
          extra_keys
        }

        let(:updated_list_env) {
          list = change_key_info(
            detailed_kv_list_results("#{backend} #{env}", false))

          extra_keys, extra_list = create_key_info(created_key_names,
            created_binary_key_names, env, backend)
          list.deep_merge!(extra_list)
          list
        }

        let(:updated_list_global) {
          list = change_key_info(
            detailed_kv_list_results("#{backend} global", true))
          extra_keys, extra_list = create_key_info(created_key_names,
            created_binary_key_names, nil, backend)
          list.deep_merge!(extra_list)
          list
        }

        let(:out_root_path) { "/var/kv_test/#{backend}" }

        include_examples 'kv put create operation test', host, env, backend_opt
        include_examples 'kv use created/modified keys test', host, env
      end
    end
  end
end
