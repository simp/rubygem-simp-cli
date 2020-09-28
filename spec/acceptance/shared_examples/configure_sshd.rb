# Set up sshd client keepalives to try to eliminate ssh connection
# timeouts that kill the tests when the Hosts are slow VMs.
shared_examples 'configure sshd' do |host|
  let(:manifest) {
    <<~EOM
      sshd_config { 'ClientAliveInterval':
        ensure => present,
        value  => 20,
      }

      sshd_config { 'ClientAliveCountMax':
        ensure => present,
        value  => 15,
      }
    EOM
  }

  it "should set ClientAlive* sshd settings on #{host}" do
    apply_manifest_on(host, manifest)
  end

  it "should reboot #{host} to restart vagrant connections with new settings" do
    host.reboot
  end
end
