shared_examples 'configure puppet env' do |host,env|

  it "should set the puppet environment to #{env} on #{host}" do
    # configure the environment for both the puppetserver and agent
    on(host, "puppet config set --section master environment #{env}")
    on(host, "puppet config set --section agent environment #{env}")
  end

  it "should reload the puppetserver on #{host} to pick up the changes" do
    status = on(host, 'puppet resource service puppetserver').stdout
    reload_cmd = nil
    if status =~ /running/
      os_major_ver = fact_on(host, 'operatingsystemmajrelease')
      reload_cmd = 'systemctl reload puppetserver'
    else
      reload_cmd = 'puppet resource service puppetserver ensure=running'
    end

    on(host, reload_cmd)
  end

  it "should wait for the reloaded puppetserver to be available on #{host}" do
    # wait for it to come up
    master_fqdn = fact_on(host, 'fqdn')
    puppetserver_status_cmd = [
      'curl -sSk',
      "--cert /etc/puppetlabs/puppet/ssl/certs/#{master_fqdn}.pem",
      "--key /etc/puppetlabs/puppet/ssl/private_keys/#{master_fqdn}.pem",
      "https://localhost:8140/production/certificate_revocation_list/ca",
      '| grep CRL'
    ].join(' ')
    retry_on(host, puppetserver_status_cmd, :retry_interval => 10)
  end
end
