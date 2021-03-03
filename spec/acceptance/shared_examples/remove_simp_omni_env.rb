require 'yaml'
shared_examples 'remove SIMP omni environment' do |host,env_name|

  let(:puppet_env_dir) { "/etc/puppetlabs/code/environments/#{env_name}" }
  let(:secondary_env_dir) { "/var/simp/environments/#{env_name}" }

  it "should remove the #{env_name} Puppet environment" do
    on(host, "rm -rf #{puppet_env_dir}")
  end

  it "should remove the #{env_name} secondary environment" do
    on(host, "rm -rf #{secondary_env_dir}")
  end
end
