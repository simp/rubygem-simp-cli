require 'spec_helper_acceptance'

test_name 'simp passgen list operations'

describe 'simp passgen list operations' do

  hosts.each do |host|

    context 'environment list' do
      it 'should only list environments containing simp-simplib module' do
        result = on(host, 'simp passgen -E').stdout
        expect(result).to match(/old_simplib/)
        expect(result).to match(/new_simplib_legacy_passgen/)
        expect(result).to match(/new_simplib_libkv_passgen/)
        expect(result).to_not match(/production/)
      end
    end

    context 'password lists' do
      let(:names) { [
        'passgen_test_default',
        'passgen_test_c0_8',
        'passgen_test_c1_1024',
        'passgen_test_c2_20',
        'passgen_test_c2_only'
      ] }

      [
        'old_simplib',
        'new_simplib_legacy_passgen',
        'new_simplib_libkv_passgen'
      ].each do |env|
        context "name list for #{env} environment" do
          it 'should list top folder names from passgen_test' do
            result = on(host, "simp passgen -e #{env} -l").stdout
            names.each do |name|
              expect(result).to match(/#{name}/)
            end
          end

          if env == 'new_simplib_libkv_passgen'
            [ 'app1', 'app2', 'app3'].each do |folder|
              it "should list #{folder} folder names from passgen_test" do
                cmd = "simp passgen -e #{env} -l --folder #{folder}"
                result = on(host, cmd).stdout
                names.each do |name|
                  expect(result).to match(/sub_#{name}/)
                end
              end
            end
          end
        end

        context "password list for #{env} environment" do
          it 'should list passwords for top folder names from passgen_test' do
            names.each do |name|
              list_result = on(host, "simp passgen -e #{env} -n #{name}").stdout
              value = on(host, "cat /var/passgen_test/#{env}-#{name}").stdout
              expect(list_result).to match(/#{Regexp.escape(value)}/)
            end
          end

          if env == 'new_simplib_libkv_passgen'
            [ 'app1', 'app2', 'app3'].each do |folder|
              it "should list passwords for #{folder}/ names from passgen_test" do
                names.each do |name|
                  cmd = "simp passgen -e #{env} -n sub_#{name} --folder #{folder}"
                  list_result = on(host, cmd).stdout

                  cmd = "cat /var/passgen_test/#{env}-#{folder}/sub_#{name}"
                  value = on(host, cmd).stdout

                  expect(list_result).to match(/#{Regexp.escape(value)}/)
                end
              end
            end
          end
        end
      end
    end
  end
end
