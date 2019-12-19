# Test 'simp kv list' operation for environment and global folders
#
# @param host Host object on which to execute test
# @param env Puppet environment
# @param backend_opt Backend option to apply to simp kv list command
# @param brief_opt Brief option to apply to simp kv list command
#
# Assumes following are in scope:
#   list_env        = List result (Hash) for / and complex/ folders for env
#                     in backend corresponding to backend_opt
#   list_global     = List result (Hash) for global / and global_complex/
#                     folders in backend corresponding to backend_opt
#   outfile          = JSON output file for 'simp kv list' operation
#
shared_examples 'kv list operation test' do |host, env, backend_opt, brief_opt|
  it "should list #{env} env keys & sub-dirs" do
    cmd = "umask 0077; simp kv list #{list_env.keys.join(',')} -o #{outfile} "\
          "-e #{env} #{backend_opt} #{brief_opt}"
    result = run_and_load_json(host, cmd, outfile)
    expect( result ).to eq(list_env)
  end

  it 'should list global keys & sub-dir names' do
    cmd = "umask 0077; simp kv list #{list_global.keys.join(',')} --global "\
          "-o #{outfile} -e #{env} #{backend_opt} #{brief_opt}"
    result = run_and_load_json(host, cmd, outfile)
    expect( result ).to eq(list_global)
  end
end
