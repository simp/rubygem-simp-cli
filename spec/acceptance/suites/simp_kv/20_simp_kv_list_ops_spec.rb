# frozen_string_literal: true

require 'spec_helper_acceptance'
require 'json'

test_name 'simp kv list operations'

describe 'simp kv list operations' do
  let(:outfile) { '/root/list.json' }

  ['production', 'dev'].each do |env|
    {
      'default' => '',
      'custom' => '--backend custom'
    }.each do |backend, backend_opt|
      hosts.each do |host|
        include_examples 'workaround beaker ssh session closures', hosts

        context "brief list for #{env} env #{backend} backend on #{host}" do
          # default and custom backend list results only differ in the key
          # metadata, which is not present in the brief listing
          let(:list_env) { brief_kv_list_results(false) }
          let(:list_global) { brief_kv_list_results(true) }

          include_examples 'kv list operation test', host, env, backend_opt, ''
        end

        context "detailed folder list for #{env} env #{backend} backend on " \
                "#{host}" do
          let(:list_env) do
            detailed_kv_list_results("#{backend} #{env}", false)
          end

          let(:list_global) do
            detailed_kv_list_results("#{backend} global", true)
          end

          include_examples 'kv list operation test', host, env, backend_opt,
                           '--no-brief'
        end
      end
    end
  end
end
