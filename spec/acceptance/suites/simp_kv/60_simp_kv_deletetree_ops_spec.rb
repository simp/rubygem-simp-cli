require 'spec_helper_acceptance'
require 'json'

test_name 'simp kv deletetree operations'

describe 'simp kv deletetree operations' do
  let(:outfile) { '/root/exists.json' }
  let(:folders_env) { [ 'complex' ] }
  let(:folders_global) { [ 'global_complex' ] }

  # In the test set up, production and dev Puppet envs both share the same
  # libkv backends (default and custom).  So, to cleanly test folder removals
  # in each environment, this test will apply changes to the default backend
  # via the production env, only, and apply changes to the custom backend via
  # the dev environment, only.
  #
  [ [ 'production', 'default', ''                 ],
    [ 'dev',        'custom',  '--backend custom' ]
  ].each do |env, backend, backend_opt|
    hosts.each do |host|
      it "should delete #{env} env folders from #{backend} backend "\
         "on #{host}" do
        cmd = "umask 0077; simp kv deletetree #{folders_env.join(',')} "\
              "-e #{env} #{backend_opt} --force"
        on(host, cmd)

        expected = folders_env.map {|key| [ key, 'absent' ] }.to_h
        cmd = "umask 0077; simp kv exists #{folders_env.join(',')} "\
              "-e #{env} #{backend_opt} -o #{outfile}"
        result = run_and_load_json(host, cmd, outfile)
        expect( result ).to eq(expected)
      end

      it "should delete global folders from #{backend} backend on #{host}" do
        cmd = "umask 0077; simp kv deletetree #{folders_global.join(',')} "\
              "--global -e #{env} #{backend_opt} --force"
        on(host, cmd)

        expected = folders_global.map {|key| [ key, 'absent' ] }.to_h
        cmd = "umask 0077; simp kv exists #{folders_global.join(',')} "\
              "--global -e #{env} #{backend_opt} -o #{outfile}"
        result = run_and_load_json(host, cmd, outfile)
        expect( result ).to eq(expected)
      end
    end
  end
end
