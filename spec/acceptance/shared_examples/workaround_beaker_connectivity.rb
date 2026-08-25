# frozen_string_literal: true

shared_examples 'workaround beaker ssh session closures' do |hosts|
  hosts.each do |host|
    context "ssh connection to #{host}" do
      it 'ensures ssh connection' do
        ensure_ssh_connection(host)
      end
    end
  end
end
