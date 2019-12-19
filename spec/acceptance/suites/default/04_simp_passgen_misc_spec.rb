require 'spec_helper_acceptance'

test_name 'simp passgen miscelleous'

describe 'simp passgen miscelleous' do

  hosts.each do |host|

    [
      'old_simplib',
      'new_simplib_legacy_passgen',
      'new_simplib_libkv_passgen'
    ].each do |env|

      if env == 'new_simplib_libkv_passgen'
        context 'Specifying libkv backend' do
          let(:valid_backend) { 'default' }
          let(:names) { [
            'passgen_test_default',
            'passgen_test_c0_8',
            'passgen_test_c1_1024',
            'passgen_test_c2_20',
            'passgen_test_c2_only'
          ] }

          it "should list names when valid backend specified in #{env}" do
            cmd = "simp passgen list -e #{env} --backend #{valid_backend}"
            result = on(host, cmd).stdout

            names.each do |name|
              expect(result).to match(/#{name}/)
            end
          end

          it "should list passwords when valid backend specified in #{env}" do
            cmd = "simp passgen show #{names.first} -e #{env} --backend #{valid_backend}"
            result = on(host, cmd).stdout
            expect(result).to match(/Current:/)
          end

          it "should set passwords when valid backend specified in #{env}" do
            cmd = "simp passgen set new_name -e #{env} --backend #{valid_backend} --auto-gen"
            on(host, cmd)
            result = on(host, "simp passgen list -e #{env} --backend #{valid_backend}").stdout
            expect(result).to match(/new_name/)
          end

          it "should remove passwords when valid backend specified in #{env}" do
            cmd = "simp passgen remove new_name -e #{env} --backend #{valid_backend} --force"
            on(host, cmd)
            result = on(host, "simp passgen list -e #{env} --backend #{valid_backend}").stdout
            expect(result).to_not match(/new_name/)
          end
        end
      end

      context 'Error handling' do
        let(:valid_name) { 'passgen_test_default' }
        let(:invalid_name) { 'passgen_test_oops' }
        let(:invalid_backend) { 'oops_backend' }

        it "should fail password list when invalid name specified in #{env}" do
          cmd = "simp passgen show #{invalid_name} -e #{env}"
          on(host, cmd, :acceptable_exit_codes => 1)
        end

        it "should fail password remove when invalid name specified in #{env}" do
          cmd = "simp passgen remove #{invalid_name} -e #{env} --force"
          on(host, cmd, :acceptable_exit_codes => 1)
        end

        if env == 'new_simplib_libkv_passgen'
          it "should fail name list when invalid backend specified in #{env}" do
            cmd = "simp passgen list -e #{env} --backend #{invalid_backend}"
            on(host, cmd, :acceptable_exit_codes => 1)
          end

          it "should fail password list when invalid backend specified in #{env}" do
            cmd = "simp passgen show #{valid_name} -e #{env} --backend #{invalid_backend}"
            on(host, cmd, :acceptable_exit_codes => 1)
          end

          it "should fail password set when invalid backend specified in #{env}" do
            cmd = "simp passgen set new_name -e #{env} --backend #{invalid_backend} --auto-gen"
            on(host, cmd, :acceptable_exit_codes => 1)
          end

          it "should fail password remove when invalid backend specified in #{env}" do
            cmd = "simp passgen remove #{valid_name} -e #{env} --backend #{invalid_backend} --force"
            on(host, cmd, :acceptable_exit_codes => 1)
          end
        end
      end

    end #[...].each do |env|
  end # hosts.each
end #describe...
