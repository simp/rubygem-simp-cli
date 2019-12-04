# Test 'simp kv put' operation that creates environment and global keys
#
# @param host Host object on which to execute test
# @param env Puppet environment
# @param backend_opt Backend option to apply to kv commands
#
# Assumes the following are in scope:
#   created_keys_env    = Key info for new env keys in / and complex/ folders
#   created_keys_global = Key info for new global keys in / and global_complex/
#                         folders
#   updated_list_env    = New list result (Hash) for / and complex/ folders
#                         for env in backend corresponding to backend_opt
#   updated_list_global = New list result (Hash) for global / and
#                         global_complex/ for env in backend corresponding
#                         to backend_opt
#   infile              = JSON input file for 'simp kv put' operation
#   outfile             = JSON output file for 'simp kv list' operation
shared_examples 'kv put create operation test' do |host, env, backend_opt|
  it "should store key info for new #{env} env keys" do
    create_remote_file(host, infile, created_keys_env.to_json)
    keys = created_keys_env.keys
    store_cmd = "umask 0077; simp kv put -i #{infile} --force -e #{env} "\
                "#{backend_opt}"
    on(host, store_cmd)

    list_cmd = "umask 0077; simp kv list /,complex --no-brief -e #{env} "\
               "-o #{outfile} #{backend_opt}"
    result = run_and_load_json(host, list_cmd, outfile)
    expect( result ).to eq( updated_list_env )
  end

  it 'should store new key info for new global keys' do
    create_remote_file(host, infile, created_keys_global.to_json)
    keys = created_keys_global.keys
    store_cmd = "umask 0077; simp kv put -i #{infile} --force -e #{env} "\
                " --global #{backend_opt}"
    on(host, store_cmd)

    list_cmd = "umask 0077; simp kv list /,global_complex --no-brief "\
               "-o #{outfile} --global #{backend_opt}"
    result = run_and_load_json(host, list_cmd, outfile)
    expect( result ).to eq( updated_list_global )
  end
end
