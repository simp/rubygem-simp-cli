require 'spec_helper_acceptance'

test_name 'simp kv set up'

describe 'simp kv set up' do

  hosts.each do |host|
    context 'environment set up' do
      include_examples 'kv test environments set up', host
    end

    context 'initial key/value generation' do
      [ 'production', 'dev' ].each do |env|
        context 'puppet agent prep' do
          include_examples 'configure puppet env', host, env
        end

        context 'puppet agent runs' do
          it 'should add test class to store key info in backends' do
           default_yaml_file = File.join( '/etc/puppetlabs/code/environments',
               env, 'data', 'default.yaml')

            hieradata = YAML.load( on(host, "cat #{default_yaml_file}").stdout )
            hieradata['classes'] = [ 'kv_test::store' ]
            create_remote_file(host, default_yaml_file, hieradata.to_yaml)
            on(host, "cat #{default_yaml_file}")
          end

          it 'should apply manifest' do
            retry_on(host, 'puppet agent -t', :desired_exit_codes => [0],
              :max_retries => 5, :verbose => true.to_s)
          end
        end
      end
    end
  end
end
