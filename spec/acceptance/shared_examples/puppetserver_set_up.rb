
shared_examples 'puppetserver set up' do |master|

  context 'puppetserver install and set up' do
    it 'should ensure hostname is set to a FQDN' do
      # FQDN fact seems to be correct even though all the places hostname must
      # be set may not be.
      fqdn = fact_on(master, 'fqdn')
      on(master, "hostname #{fqdn}")
      on(master, "echo #{fqdn} > /etc/hostname")
      on(master, "sed -i '/HOSTNAME/d' /etc/sysconfig/network")
      on(master, "echo HOSTNAME=#{fqdn} >> /etc/sysconfig/network")
    end


    it 'should install puppetserver' do
      master.install_package('puppetserver')
    end

    it 'should configure agent to talk to puppetserver' do
      master_fqdn = fact_on(master, 'fqdn')
      on(master, "puppet config set server #{master_fqdn}")
    end
  end
end
