# frozen_string_literal: true

require 'spec_helper_acceptance'
require 'json'

test_name 'simp kv get operations'

describe 'simp kv get operations' do
  let(:outfile) { '/root/get.json' }

  ['production', 'dev'].each do |env|
    {
      'default' => '',
      'custom' => '--backend custom'
    }.each do |backend, backend_opt|
      hosts.each do |host|
        include_examples 'workaround beaker ssh session closures', hosts

        # The subfolders in keys_sub_env and keys_sub_global are based on
        # initial keys persisted
        # TODO Select the subfolders to use based on initial_key_info() and
        #      initial_binary_key_info(), which contain the list of initial
        #      keys persisted
        context "key get for #{env} env #{backend} on #{host}" do
          let(:keys_root_env) do
            keys_info('/', detailed_kv_list_results("#{backend} #{env}", false))
          end

          let(:keys_sub_env) do
            keys_info(
              'complex',
              detailed_kv_list_results("#{backend} #{env}", false),
            )
          end

          let(:keys_root_global) do
            keys_info('/', detailed_kv_list_results("#{backend} global", true))
          end

          let(:keys_sub_global) do
            keys_info(
              'global_complex',
              detailed_kv_list_results("#{backend} global", true),
            )
          end

          it 'retrieves key info for top-level env keys from backend' do
            keys = keys_root_env.keys
            cmd = "umask 0077; simp kv get #{keys.join(',')} -o #{outfile} " \
                  "-e #{env} #{backend_opt}"
            result = run_and_load_json(host, cmd, outfile)
            expect(result).to eq(keys_root_env)
          end

          it 'retrieves key info for sub-folder env keys from backend' do
            keys = keys_sub_env.keys
            cmd = "umask 0077; simp kv get #{keys.join(',')} -o #{outfile} " \
                  "-e #{env} #{backend_opt}"
            result = run_and_load_json(host, cmd, outfile)
            expect(result).to eq(keys_sub_env)
          end

          it 'retrieves key info for top-level global keys from backend' do
            keys = keys_root_global.keys
            cmd = "umask 0077; simp kv get #{keys.join(',')} --global " \
                  "-o #{outfile} -e #{env} #{backend_opt}"
            result = run_and_load_json(host, cmd, outfile)
            expect(result).to eq(keys_root_global)
          end

          it 'retrieves key info for sub-folder global keys from backend' do
            keys = keys_sub_global.keys
            cmd = "umask 0077; simp kv get #{keys.join(',')} --global " \
                  "-o #{outfile} -e #{env} #{backend_opt}"
            result = run_and_load_json(host, cmd, outfile)
            expect(result).to eq(keys_sub_global)
          end
        end
      end
    end
  end
end
