require 'spec_helper_acceptance'

# global variable to hold results from an example for comparison in
# later examples
saved_new_passwords = {}

test_name 'simp passgen create and remove passwords'

describe 'simp passgen create and remove passwords' do
  let(:new_names) { ['passgen_test_default_new1', 'passgen_test_default_new2'] }

  hosts.each do |host|
    [
      'old_simplib',
      'new_simplib_legacy_passgen',
      'new_simplib_libkv_passgen'
    ].each do |env|
      context 'Password name creation' do
        it "should create new passwords in #{env}" do
          new_names.each do |name|
            cmd = "simp passgen -e #{env} -s #{name} --auto-gen"
            set_result = on(host, cmd).stdout
            new_password = set_result.match(/.*new password: (.*)/m)[1].chomp!.chomp!
            saved_new_passwords[name] = new_password
          end
        end

        it "should list the new password names in #{env}" do
          result = on(host, "simp passgen -e #{env} -l").stdout
          new_names.each do |name|
            expect(result).to match(/#{name}/)
          end
        end
      end

      context 'Use of externally created password in a manifest' do
        context 'puppet agent prep' do
          include_examples 'configure puppet env', host, env
        end

        context 'puppet agent run' do
          it 'should add extra passwords to passgen_test via hieradata' do
            default_yaml_file = File.join( '/etc/puppetlabs/code/environments',
               env, 'data', 'default.yaml')

            hieradata = YAML.load( on(host, "cat #{default_yaml_file}").stdout )
            hieradata['passgen_test::extra_keys'] = new_names
            create_remote_file(host, default_yaml_file, hieradata.to_yaml)
            on(host, "cat #{default_yaml_file}")
          end

          it 'should apply manifest to add extra persisted passwords' do
            retry_on(host, 'puppet agent -t', :desired_exit_codes => [0],
              :max_retries => 5, :verbose => true.to_s)
          end

          [
           "/var/passgen_test/#{env}-passgen_test_default_new1",
           "/var/passgen_test/#{env}-passgen_test_default_new2",
          ].each do |file|
            it "should create #{file} with the externally pre-set password" do
              expect( file_exists_on(host, file) ).to be true
              name = File.basename(file).gsub(/#{env}\-/,'')
              preset_value = saved_new_passwords[name]
              curr_value = on(host, "cat #{file}").stdout
              expect(curr_value).to eq(preset_value)
            end
          end
        end
      end

      context 'Password name removal' do
        it "should remove passwords in #{env}" do
          new_names.each do |name|
            cmd = "simp passgen -e #{env} -r #{name} --force-remove"
            on(host, cmd).stdout
          end

          result = on(host, "simp passgen -e #{env} -l").stdout
          new_names.each do |name|
            expect(result).to_not match(/#{name}/)
          end
        end
      end
    end #[...].each do |env|
  end # hosts.each
end #describe...
