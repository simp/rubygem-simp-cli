# frozen_string_literal: true

require 'spec_helper_acceptance'

test_name 'simp cli set up'

describe 'simp cli set up' do
  hosts.each do |host|
    context 'Puppet server set up' do
      it_behaves_like 'configure sshd', host
      it_behaves_like 'fixtures move', host

      it_behaves_like 'workaround beaker ssh session closures', hosts
      it_behaves_like 'simp asset manual install', host

      it_behaves_like 'workaround beaker ssh session closures', hosts
      it_behaves_like 'puppetserver set up', host
    end
  end
end
