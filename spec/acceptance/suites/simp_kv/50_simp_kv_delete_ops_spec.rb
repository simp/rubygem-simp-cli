require 'spec_helper_acceptance'
require 'json'

test_name 'simp kv delete operations'

describe 'simp kv delete operations' do
  let(:outfile) { '/root/exists.json' }
  let(:keys_env) { [ 'boolean', 'string', 'complex/hash'] }
  let(:keys_global) { ['global_float', 'global_complex/array_integers'] }

  # In the test set up, production and dev Puppet envs both share the same
  # libkv backends (default and custom).  So, to cleanly test key removals
  # in each environment, this test will apply changes to the default backend
  # via the production env, only, and apply changes to the custom backend via
  # the dev environment, only.
  #
  [ [ 'production', 'default', ''                 ],
    [ 'dev',        'custom',  '--backend custom' ]
  ].each do |env, backend, backend_opt|
    hosts.each do |host|
      it "should delete #{env} env keys from #{backend} backend on #{host}" do
        cmd = "umask 0077; simp kv delete #{keys_env.join(',')} -e #{env} "\
              "#{backend_opt} --force"
        on(host, cmd)

        expected = keys_env.map {|key| [ key, 'absent' ] }.to_h
        cmd = "umask 0077; simp kv exists #{keys_env.join(',')} -e #{env} "\
              "#{backend_opt} -o #{outfile}"
        result = run_and_load_json(host, cmd, outfile)
        expect( result ).to eq(expected)
      end

      it "should delete global keys from #{backend} backend on #{host}" do
        cmd = "umask 0077; simp kv delete #{keys_global.join(',')} --global "\
              "-e #{env} #{backend_opt} --force"
        on(host, cmd)

        expected = keys_global.map {|key| [ key, 'absent' ] }.to_h
        cmd = "umask 0077; simp kv exists #{keys_global.join(',')} --global "\
              "-e #{env} #{backend_opt} -o #{outfile}"
        result = run_and_load_json(host, cmd, outfile)
        expect( result ).to eq(expected)
      end
    end
  end
end
