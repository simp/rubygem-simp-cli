require 'spec_helper_acceptance'

test_name 'simp cli set up'

describe 'simp cli set up' do

  hosts.each do |host|
    context 'Puppet master set up' do
      include_examples 'fixtures move', host

      include_examples 'workaround beaker ssh session closures', hosts
      include_examples 'simp asset manual install', host

      include_examples 'workaround beaker ssh session closures', hosts
      include_examples 'puppetserver set up', host
    end
  end
end
