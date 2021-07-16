
shared_examples 'puppetserver set up' do |server|

  context 'puppetserver install and set up' do
    it 'should ensure hostname is set to a FQDN' do
      # FQDN fact seems to be correct even though all the places hostname must
      # be set may not be.
#FIXME hostnamectl?
      fqdn = fact_on(server, 'fqdn')
      on(server, "hostname #{fqdn}")
      on(server, "echo #{fqdn} > /etc/hostname")
      on(server, "sed -i '/HOSTNAME/d' /etc/sysconfig/network")
      on(server, "echo HOSTNAME=#{fqdn} >> /etc/sysconfig/network")
    end


    it 'should install puppetserver' do
      server.install_package('puppetserver')
    end

    it 'should configure agent to talk to puppetserver' do
      server_fqdn = fact_on(server, 'fqdn')
      on(server, "puppet config set server #{server_fqdn}")
    end
  end
end
