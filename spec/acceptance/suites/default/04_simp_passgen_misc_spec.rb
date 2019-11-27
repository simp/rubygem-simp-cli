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
            cmd = "simp passgen -e #{env} -l --backend #{valid_backend}"
            result = on(host, cmd).stdout

            names.each do |name|
              expect(result).to match(/#{name}/)
            end
          end

          it "should list passwords when valid backend specified in #{env}" do
            cmd = "simp passgen -e #{env} -n #{names.first} --backend #{valid_backend}"
            result = on(host, cmd).stdout
            expect(result).to match(/Current:/)
          end

          it "should set passwords when valid backend specified in #{env}" do
            cmd = "simp passgen -e #{env} -s new_name --backend #{valid_backend} --auto-gen"
            on(host, cmd)
            result = on(host, "simp passgen -e #{env} -l --backend #{valid_backend}").stdout
            expect(result).to match(/new_name/)
          end

          it "should remove passwords when valid backend specified in #{env}" do
            cmd = "simp passgen -e #{env} -r new_name --backend #{valid_backend} --force-remove"
            on(host, cmd)
            result = on(host, "simp passgen -e #{env} -l --backend #{valid_backend}").stdout
            expect(result).to_not match(/new_name/)
          end
        end
      end

      context 'Error handling' do
        let(:valid_name) { 'passgen_test_default' }
        let(:invalid_name) { 'passgen_test_oops' }
        let(:invalid_backend) { 'oops_backend' }

        it "should fail password list when invalid name specified in #{env}" do
          cmd = "simp passgen -e #{env} -n #{invalid_name}"
          on(host, cmd, :acceptable_exit_codes => 1)
        end

        it "should fail password remove when invalid name specified in #{env}" do
          cmd = "simp passgen -e #{env} -r #{invalid_name} --force-remove"
          on(host, cmd, :acceptable_exit_codes => 1)
        end

        if env == 'new_simplib_libkv_passgen'
          it "should fail name list when invalid backend specified in #{env}" do
            cmd = "simp passgen -e #{env} -l --backend #{invalid_backend}"
            on(host, cmd, :acceptable_exit_codes => 1)
          end

          it "should fail password list when invalid backend specified in #{env}" do
            cmd = "simp passgen -e #{env} -n #{valid_name} --backend #{invalid_backend}"
            on(host, cmd, :acceptable_exit_codes => 1)
          end

          it "should fail password set when invalid backend specified in #{env}" do
            cmd = "simp passgen -e #{env} -s new_name --backend #{invalid_backend} --auto-gen"
            on(host, cmd, :acceptable_exit_codes => 1)
          end

          it "should fail password remove when invalid backend specified in #{env}" do
            cmd = "simp passgen -e #{env} -r #{valid_name} --backend #{invalid_backend} --force-remove"
            on(host, cmd, :acceptable_exit_codes => 1)
          end
        end
      end

    end #[...].each do |env|
  end # hosts.each
end #describe...
