require 'spec_helper_acceptance'

test_name 'simp passgen set up'

describe 'simp passgen set up' do

  context 'Puppet master set up' do
    hosts.each do |host|
      include_examples 'fixtures move', host

      include_examples 'workaround beaker ssh session closures', hosts
      include_examples 'simp asset manual install', host

      include_examples 'workaround beaker ssh session closures', hosts
      include_examples 'passgen test environments set up', host

      include_examples 'workaround beaker ssh session closures', hosts
      include_examples 'puppetserver set up', host
    end
  end


  context 'initial passgen secret generation' do
    [
      'old_simplib',
      'new_simplib_legacy_passgen',
      'new_simplib_simpkv_passgen'
    ].each do |env|
    hosts.each do |host|
        context 'puppet agent prep' do
          include_examples 'workaround beaker ssh session closures', hosts
          include_examples 'configure puppet env', host, env
        end

        context 'puppet agent run' do
          include_examples 'workaround beaker ssh session closures', hosts

          it 'should apply manifest to generate passwords and persist to files' do
            retry_on(host, 'puppet agent -t', :desired_exit_codes => [0],
              :max_retries => 5, :verbose => true.to_s)
          end

          [
           "/var/passgen_test/#{env}-passgen_test_default",
           "/var/passgen_test/#{env}-passgen_test_c0_8",
           "/var/passgen_test/#{env}-passgen_test_c1_1024",
           "/var/passgen_test/#{env}-passgen_test_c2_20",
           "/var/passgen_test/#{env}-passgen_test_c2_only"
          ].each do |file|
            it "should create #{file}" do
              expect( file_exists_on(host, file) ).to be true
            end
          end

          if env == 'new_simplib_simpkv_passgen'
            [ 'app1', 'app2', 'app3'].each do |folder|
              [
               "/var/passgen_test/#{env}-#{folder}/sub_passgen_test_default",
               "/var/passgen_test/#{env}-#{folder}/sub_passgen_test_c0_8",
               "/var/passgen_test/#{env}-#{folder}/sub_passgen_test_c1_1024",
               "/var/passgen_test/#{env}-#{folder}/sub_passgen_test_c2_20",
               "/var/passgen_test/#{env}-#{folder}/sub_passgen_test_c2_only"
              ].each do |file|
                it "should create #{file}" do
                  expect( file_exists_on(host, file) ).to be true
                end
              end
            end
          end
        end
      end
    end
  end
end
