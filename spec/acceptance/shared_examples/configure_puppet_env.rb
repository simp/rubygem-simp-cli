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
      if os_major_ver.to_s == '6'
        reload_cmd = 'service puppetserver reload'
      else
        reload_cmd = 'systemctl reload puppetserver'
      end
    else
      reload_cmd = 'puppet resource service puppetserver ensure=running'
    end

    on(host, reload_cmd)
  end

  it "should wait for the reloaded puppetserver to be available on #{host}" do
    # wait for it to come up
    master_fqdn = fact_on(host, 'fqdn')
    puppetserver_status_cmd = [
      'curl -sk',
      "--cert /etc/puppetlabs/puppet/ssl/certs/#{master_fqdn}.pem",
      "--key /etc/puppetlabs/puppet/ssl/private_keys/#{master_fqdn}.pem",
      "https://#{master_fqdn}:8140/status/v1/services",
      '| python -m json.tool',
      '| grep state',
      '| grep running'
    ].join(' ')
    retry_on(host, puppetserver_status_cmd, :retry_interval => 10)
  end
end
