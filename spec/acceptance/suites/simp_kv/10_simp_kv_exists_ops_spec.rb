require 'spec_helper_acceptance'
require 'json'

test_name 'simp kv exists operations'

describe 'simp kv exists operations' do
  let(:outfile) { '/root/exists.json' }

  # The keys in exists_env and exists_global are based on initial keys persisted
  # TODO Generate these expected results based on initial_key_info() and
  #      initial_binary_key_info(), which contain the list of initial
  #      keys persisted
  let(:exists_env) { {
    # existing environment keys
    'boolean'           => 'present',
    'string'            => 'present',

    # non-existent paths
    'missing1'          => 'absent',
    'missing2/missing3' => 'absent',

    # existing environment sub-folders
    'complex'           => 'present',

    # existing keys in environment sub-folders
    'complex/hash'      => 'present'
  } }

  let(:exists_global) { {
    # top level keys
    'global_float'                  => 'present',
    'global_integer'                => 'present',

    # top level folders
    'global_complex'                => 'present',

    # existing sub-folder keys'
    'global_complex/array_integers' => 'present',

    # non-existent keys
    'missing4/missing5'       => 'absent'
  } }


  [ 'production', 'dev', ].each do |env|
    {
      'default' => '',
      'custom'  => '--backend custom'
    }.each do |backend, backend_opt|
      hosts.each do |host|

        include_examples 'workaround beaker ssh session closures', hosts

        it "should report existence of #{env} env folders & keys in "\
           "#{backend} backend on #{host}" do

          cmd = "umask 0077; simp kv exists #{exists_env.keys.join(',')} "\
                "-o #{outfile} -e #{env} #{backend_opt}"
          result = run_and_load_json(host, cmd, outfile)
          expect( result ).to eq(exists_env)
        end

        it "should report existence of global folders & keys in "\
           "#{backend} backend on #{host}" do

          cmd = "umask 0077; simp kv exists #{exists_global.keys.join(',')} "\
                "--global -o #{outfile} -e #{env} #{backend_opt}"
          result = run_and_load_json(host, cmd, outfile)
          expect( result ).to eq(exists_global)
        end
      end
    end
  end
end
