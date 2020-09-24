require 'spec_helper_acceptance'
require 'json'

test_name 'simp kv errors'

describe 'simp kv errors' do

  [ 'production', 'dev', ].each do |env|
    context "invalid folders/keys for #{env} env" do
      let(:invalid_folder) { 'oops_folder' }
      let(:invalid_key) { 'oops_key' }
      {
        'default' => '',
        'custom'  => '--backend custom'
      }.each do |backend, backend_opt|
        hosts.each do |host|
          include_examples 'workaround beaker ssh session closures', hosts

          it "should fail list if folder does not exist in #{backend} "\
             "on #{host}" do
            cmd = "umask 0077; simp kv list #{invalid_folder} -e #{env} "\
                  "#{backend_opt}"
            on(host, cmd, :acceptable_exit_codes => 1)
          end

          it "should fail get if key does not exist in #{backend} "\
             "on #{host}" do
            cmd = "umask 0077; simp kv get #{invalid_key} -e #{env} "\
                  "#{backend_opt}"
            on(host, cmd, :acceptable_exit_codes => 1)
          end

          it "should fail delete if key does not exist in #{backend} "\
             "on #{host}" do
            cmd = "umask 0077; simp kv delete #{invalid_key} -e #{env} "\
                  "#{backend_opt} --force"
            on(host, cmd, :acceptable_exit_codes => 1)
          end

          it "should fail deletetree if folder does not exist in #{backend} "\
             "on #{host}" do
            cmd = "umask 0077; simp kv deletetree #{invalid_folder} -e #{env} "\
                  "#{backend_opt} --force"
            on(host, cmd, :acceptable_exit_codes => 1)
          end
        end
      end
    end

    context "invalid backend for #{env} env" do
      # folder/key do not matter because backend config will fail first
      let(:folder) { 'some_folder' }
      let(:key) { 'some_key' }
      let(:invalid_backend_opt) { '--backend oops_backend' }
      let(:infile) { '/root/put.json' }

      hosts.each do |host|
        include_examples 'workaround beaker ssh session closures', hosts

        it "should fail delete if backend is invalid in #{env} env "\
           "on #{host}" do
          cmd = "umask 0077; simp kv delete #{key} -e #{env} "\
                "#{invalid_backend_opt} --force"
          on(host, cmd, :acceptable_exit_codes => 1)
        end

        it "should fail deletetree if backend is invalid in #{env} env "\
           "on #{host}" do
          cmd = "umask 0077; simp kv deletetree #{folder} -e #{env} "\
                "#{invalid_backend_opt} --force"
          on(host, cmd, :acceptable_exit_codes => 1)
        end

        it "should fail exists if backend is invalid in #{env} env "\
           "on #{host}" do
          cmd = "umask 0077; simp kv exists #{key} -e #{env} "\
                "#{invalid_backend_opt}"
          on(host, cmd, :acceptable_exit_codes => 1)
        end

        it "should fail get if backend is invalid in #{env} env "\
           "on #{host}" do
          cmd = "umask 0077; simp kv get #{key} -e #{env} "\
                "#{invalid_backend_opt}"
          on(host, cmd, :acceptable_exit_codes => 1)
        end

        it "should fail list if backend is invalid in #{env} env "\
           "on #{host}" do
          cmd = "umask 0077; simp kv list #{folder} -e #{env} "\
                "#{invalid_backend_opt}"
          on(host, cmd, :acceptable_exit_codes => 1)
        end

        it "should fail put if backend is invalid in #{env} env "\
           "on #{host}" do
          keys = { key => { 'value' => 1, 'metadata' => {} } }
          create_remote_file(host, infile, keys.to_json)
          cmd = "umask 0077; simp kv put -i #{infile} -e #{env} "\
                "#{invalid_backend_opt} --force"
          on(host, cmd, :acceptable_exit_codes => 1)
        end
      end
    end
  end
end
