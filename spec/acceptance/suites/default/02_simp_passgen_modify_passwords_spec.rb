require 'spec_helper_acceptance'
require 'timeout'

# global variable to hold results from an example for comparison in
# later examples
saved_latest_passwords = {}

def validate_password(password, options)
  expect(password.length).to eq(options[:length])

  default_chars = (("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a).map do|x|
    x = Regexp.escape(x)
  end

  safe_special_chars = ['@','%','-','_','+','=','~'].map do |x|
    x = Regexp.escape(x)
  end

  unsafe_special_chars = (((' '..'/').to_a + ('['..'`').to_a + ('{'..'~').to_a)).map do |x|
    x = Regexp.escape(x)
  end - safe_special_chars

  chars_to_match = []
  chars_to_not_match = []
  if options[:complexity] == 0
    chars_to_match += default_chars
    chars_to_not_match += safe_special_chars
    chars_to_not_match += unsafe_special_chars
  else
    if options[:complexity] == 1
      chars_to_match += safe_special_chars
      chars_to_not_match += unsafe_special_chars
    else
      chars_to_match += safe_special_chars
      chars_to_match += unsafe_special_chars
    end

    if options[:complex_only]
      chars_to_not_match += default_chars
    else
      chars_to_match += default_chars
    end
  end

  expect(password).to match(/(#{chars_to_match.join('|')})/)
  unless chars_to_not_match.empty?
    expect(password).to_not match(/(#{chars_to_not_match.join('|')})/)
  end
end

test_name 'simp passgen modify existing passwords'

describe 'simp passgen modify existing passwords' do
  let(:names) { {
    'passgen_test_default' =>
      { :complexity => 0, :complex_only => false, :length =>32 },
    'passgen_test_c0_8'    =>
      { :complexity => 0, :complex_only => false, :length => 8 },
    'passgen_test_c1_1024' =>
      { :complexity => 1, :complex_only => false, :length => 1024 },
    'passgen_test_c2_20'   =>
      { :complexity => 2, :complex_only => false, :length => 20 },
    'passgen_test_c2_only' =>
      { :complexity => 2, :complex_only => true,  :length => 32 }
  } }


  hosts.each do |host|
    [
      'old_simplib',
      'new_simplib_legacy_passgen',
      'new_simplib_libkv_passgen'
    ].each do |env|
      context 'Password auto-regeneration' do
        context 'using defaults' do

          if env == 'new_simplib_libkv_passgen'
            it "should regen passwords with current length+complexity+complex_only in #{env}" do
              saved_latest_passwords.clear
              names.each do |name, options|
                cmd = "simp passgen -e #{env} -s #{name} --auto-gen"
                set_result = on(host, cmd).stdout
                new_password = set_result.match(/.*new password: (.*)/)[1]
                saved_latest_passwords[name] = new_password

                validate_password(new_password, options)
              end

              [ 'app1', 'app2', 'app3'].each do |folder|
                names.each do |name, options|
                  cmd = "simp passgen -e #{env} -s sub_#{name} --auto-gen --folder #{folder}"
                  set_result = on(host, cmd).stdout
                  new_password = set_result.match(/.*new password: (.*)/)[1]
                  saved_latest_passwords["#{folder}/sub_#{name}"] = new_password

                  validate_password(new_password, options)
                end
              end
            end
          else
            # legacy passgen does not store complexity/complex_only along with
            # the password, so the defaults for those settings are used instead of
            # the settings used to generate the original password.
            it "should regen passwords with current length in #{env}" do
              saved_latest_passwords.clear
              names.each do |name, options|
                cmd = "simp passgen -e #{env} -s #{name} --auto-gen"
                set_result = on(host, cmd).stdout
                new_password = set_result.match(/.*new password: (.*)/)[1]
                saved_latest_passwords[name] = new_password

                expect(new_password.length).to eq(options[:length])
              end
            end
          end

          it "should list current and previous passwords in top folder in #{env}" do
            names.keys.each do |name|
              list_result = on(host, "simp passgen -e #{env} -n #{name}").stdout

              curr_value = saved_latest_passwords[name]
              prev_value = on(host, "cat /var/passgen_test/#{env}-#{name}").stdout
              expect(list_result).to match(/Current:  #{Regexp.escape(curr_value)}/m)
              expect(list_result).to match(/Previous: #{Regexp.escape(prev_value)}/m)
            end
          end

          if env == 'new_simplib_libkv_passgen'
            [ 'app1', 'app2', 'app3'].each do |folder|
              it "should list current and previous passwords for #{folder}/ names in #{env}" do
                names.keys.each do |name|
                  cmd = "simp passgen -e #{env} -n sub_#{name} --folder #{folder}"
                  list_result = on(host, cmd).stdout

                  curr_value = saved_latest_passwords["#{folder}/sub_#{name}"]
                  cmd = "cat /var/passgen_test/#{env}-#{folder}/sub_#{name}"
                  prev_value = on(host, cmd).stdout
                  expect(list_result).to match(/Current:  #{Regexp.escape(curr_value)}/m)
                  expect(list_result).to match(/Previous: #{Regexp.escape(prev_value)}/m)
                end
              end
            end
          end
        end  # context 'using defaults' do

        context 'specifying characteristics' do
          it "should regen passwords with specified length+complexity+complex_only in #{env}" do
            names.each do |name, options|
              cmd = "simp passgen -e #{env} -s #{name} --auto-gen " +
                "--complexity=#{options[:complexity]} " +
                "--length=#{options[:length]}"
              cmd += ' --complex_only' if options[:complex_only]
              set_result = on(host, cmd).stdout
              new_password = set_result.match(/.*new password: (.*)/)[1]
              saved_latest_passwords[name] = new_password

              validate_password(new_password, options)
            end
          end
        end  # context 'specifying characteristics' do
      end # context 'Password auto-regeneration' do

      context 'Password input by user' do
        it 'should accept user entered password' do
          # Just spot check one name for this test:
          #  passgen_test_c0_8 - complexity 0, length 8
          stdin = "password\n"*2
          cmd = "simp passgen -e #{env} -s passgen_test_c0_8"
          retries = 3
          begin
            # sometimes :pty + :stdin doesn't work properly...the text in :stdin
            # doesn't appear to be sent
            Timeout::timeout(20) do
              set_result = on(host, cmd, { :pty => true, :stdin => stdin }).stdout
              new_password = set_result.match(/.*new password: (.*)/)[1]
              expect(new_password).to eq('password')
              saved_latest_passwords['passgen_test_c0_8'] = 'password'
            end
          rescue Timeout::TimeoutError => e
            retries -= 1
            if retries < 0
              fail('Failed to set password simulating user input')
            else
              puts 'Password set simulating user input failed. Retrying'
              retry
            end
          end
        end
      end

      context "Applying changes in #{env}" do
        context 'puppet agent prep' do
          include_examples 'configure puppet env', host, env
        end

        context 'puppet agent run' do
          it 'should apply manifest to update persisted passwords' do
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
            it "should update file #{file} with latest password" do
              name = File.basename(file).gsub(/#{env}\-/,'')
              curr_simp_passgen_value = saved_latest_passwords[name]
              curr_test_value = on(host, "cat #{file}").stdout
              expect(curr_test_value).to eq(curr_simp_passgen_value)
            end
          end

          if env == 'new_simplib_libkv_passgen'
            [ 'app1', 'app2', 'app3'].each do |folder|
              [
               "/var/passgen_test/#{env}-#{folder}/sub_passgen_test_default",
               "/var/passgen_test/#{env}-#{folder}/sub_passgen_test_c0_8",
               "/var/passgen_test/#{env}-#{folder}/sub_passgen_test_c1_1024",
               "/var/passgen_test/#{env}-#{folder}/sub_passgen_test_c2_20",
               "/var/passgen_test/#{env}-#{folder}/sub_passgen_test_c2_only"
              ].each do |file|
                it "should update file #{file} with latest password" do
                  name = "#{folder}/#{File.basename(file)}"
                  curr_simp_passgen_value = saved_latest_passwords[name]
                  curr_test_value = on(host, "cat #{file}").stdout
                  expect(curr_test_value).to eq(curr_simp_passgen_value)
                end
              end
            end
          end
        end
      end # Applying changes in...
    end #[...].each do |env|
  end # hosts.each
end #describe...
