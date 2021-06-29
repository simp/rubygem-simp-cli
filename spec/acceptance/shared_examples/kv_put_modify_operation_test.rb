# Test 'simp kv put' operation that modifies environment and global keys
#
# @param host Host object on which to execute test
# @param env Puppet environment
# @param backend_opt Backend option to apply to kv commands
#
# Assumes the following are in scope:
#   updated_list_env         = New list result (Hash) for / and complex/ folders
#                              for env in backend corresponding to backend_opt
#   updated_list_global      = New list result (Hash) for global / and
#                              global_complex/ for env in backend corresponding
#                              to backend_opt
#   infile                   = JSON input file for 'simp kv put' operation
#   outfile                  = JSON output file for 'simp kv list' operation
shared_examples 'kv put modify operation test' do |host, env, backend_opt|

  # TODO Pass in new keys/subfolders to process or automatically determine
  #      based on existing input, instead of hard-coding
  let(:updated_keys_root_env) { keys_info('/', updated_list_env) }
  let(:updated_keys_sub_env) { keys_info('complex', updated_list_env) }
  let(:updated_keys_root_global) { keys_info('/', updated_list_global) }
  let(:updated_keys_sub_global) { keys_info('global_complex', updated_list_global) }

  it "should store new key info for top-level #{env} env keys" do
    create_remote_file(host, infile, updated_keys_root_env.to_json)
    store_cmd = "umask 0077; simp kv put -i #{infile} --force -e #{env} "\
                "#{backend_opt}"
    on(host, store_cmd)

    list_cmd = "umask 0077; simp kv list / --no-brief -e #{env} -o #{outfile} "\
               "#{backend_opt}"
    result = run_and_load_json(host, list_cmd, outfile)
    expect( result['/'] ).to eq( updated_list_env['/'] )
  end

  it "should store new key info for sub-folder #{env} env keys" do
    create_remote_file(host, infile, updated_keys_sub_env.to_json)
    store_cmd = "umask 0077; simp kv put -i #{infile} --force -e #{env} "\
                "#{backend_opt}"
    on(host, store_cmd)

    list_cmd = "umask 0077; simp kv list complex --no-brief -e #{env} "\
               "-o #{outfile} #{backend_opt}"
    result = run_and_load_json(host, list_cmd, outfile)
    expect( result['complex'] ).to eq( updated_list_env['complex'] )
  end

  it 'should store new key info for top-level global keys' do
    create_remote_file(host, infile, updated_keys_root_global.to_json)
    store_cmd = "umask 0077; simp kv put -i #{infile} --force -e #{env} "\
                "--global #{backend_opt}"
    on(host, store_cmd)

    list_cmd = "umask 0077; simp kv list / --no-brief -e #{env} -o #{outfile} "\
               "--global #{backend_opt}"
    result = run_and_load_json(host, list_cmd, outfile)
    expect( result['/'] ).to eq( updated_list_global['/'] )
  end

  it 'should store new key info for sub-folder global keys' do
    create_remote_file(host, infile, updated_keys_sub_global.to_json)
    keys = updated_keys_sub_global.keys
    store_cmd = "umask 0077; simp kv put -i #{infile} --force -e #{env} "\
                "--global #{backend_opt}"
    on(host, store_cmd)

    list_cmd = "umask 0077; simp kv list global_complex --no-brief -e #{env} "\
               "-o #{outfile} --global #{backend_opt}"
    result = run_and_load_json(host, list_cmd, outfile)
    expect( result['global_complex'] ).to eq( updated_list_global['global_complex'] )
  end
end
