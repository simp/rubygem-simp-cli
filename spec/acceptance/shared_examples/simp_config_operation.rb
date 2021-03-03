require 'yaml'

# @param host Host object
# @param opts Test options Hash; see comments inline below
shared_examples 'simp config operation' do |host,options|

  opts = {
    # brief qualifier to the name of the example that runs `simp config`
    :description             => '',

    # whether this is a (mock) SIMP ISO install
    :iso_install             => false,

    # Puppet environment
    # - `simp config` default = 'production'
    # - Used in validation only
    :puppet_env              => 'production',

    # SIMP scenario
    # - `simp config` default = 'simp'
    # - Used to set `simp config` configuration when not 'simp'
    # - Used in validation
    :scenario                => 'simp',

    # Whether to set the grub password;
    # - `simp config` default = true
    # - Used to set `simp config` configuration
    # - Used in validation
    :set_grub_password       => true,

    # Whether to configure the SIMP internet repos;
    # - Only applies when :iso_install is false
    # - `simp config` default = true
    # - Used to set `simp config` configuration when false
    # - Used in validation
    :use_simp_internet_repos => true,

    # Whether the SIMP server is the LDAP server
    # - `simp config` default = true
    # - Used to set `simp config` configuration
    # - Used in validation
    :ldap_server             => true,

    # In the 'poss' scenario when the SIMP server is NOT the LDAP server, whether
    # to enable SSSD
    # - Used to set `simp config` configuration
    # - Used in validation
    :sssd                    => true,

    # List of logservers:
    # - `simp config` default = []
    # - Used to set `simp config` configuration
    # - Used in validation
    :logservers              => [],

    # List of failover logservers:
    # - `simp config` default = []
    # - Only applies when :logservers not empty
    # - Used to set `simp config` configuration
    # - Used in validation
    :failover_logservers     => [],

    # privileged local user info:
    # - Only applies when :iso_install is false
    # - When nil, no privileged user will be configured
    # - `simp config` defaults to configuring and if necessary creating a
    #   'simpadmin' user
    # - Used to pre-configure user prior to `simp config`
    # - Used to set `simp config` configuration
    # - Used in validation
    :priv_user               =>  {
      :name     => 'simpadmin',  # name of the local privileged user
      :exists   => false,        # whether user should already exist prior to `simp config`
      :has_keys => false         # whether user should have SSH authorized_keys prior to `simp config`
    },

    # additional `simp config` command line options/args
    :config_opts_to_add      => [],

    # environment variables to set when running simp config
    :env_vars                => [],

    # Interface to configure for puppetserver communication
    # - Needs to be set based on host configuration
    # - Default here is a guess!
    # - Used to set `simp config` configuration
    # - Used in validation
    :interface               => 'eth0'
  }.merge(options)

  opts[:priv_user] = nil if opts[:iso_install]
  unless opts[:priv_user].nil?
    opts[:priv_user][:name] = 'simpadmin' unless opts[:priv_user].key?(:name)

    # doesn't make sense to have SSH authorized_keys file, if the user doesn't exist
    opts[:priv_user][:has_keys] = false unless opts[:priv_user][:exists]
  end

  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
  let(:password) { 'P@ssw0rdP@ssw0rd' }
  let(:grub_pwd_hash) {
    'grub.pbkdf2.sha512.10000.DE78658C8482E4F3752B61942622345CB22BF23FECDDDCA41D9891FF7569376D3177D11945AF344267B04B44227475BDD520367D5A492EEADCBAB6AA76718AFA.2B08D03310E1514F517A59D9F1B174C73DC15B9C02010F88DC6E6FC8C869D16B9B38E9004CB6382AFE3A68BFC29E14B49C48360ED829D6EDC25E05F5609069F8'
  }

  let(:ldap_rootpw_hash) { "{SSHA}oIQoj6htrx7TnXwhTOY57ThnklOJkD8m" }
  let(:priv_user_pwd_hash) {
    '$6$l69r7t36$WZxDVhvdMZeuL0vRvOrSLMKWxxQbuK1j8t0vaEq3BW913hjOJhRNTxqlKzDflPW7ULPwkBa6xdfcca2BlGoq/.'
  }

  let(:config_opts) {
    config = [
      # `simp config` command line options

      # Force defaults if not otherwised specified and do not allow queries.
      # This means `simp config` will fail if it encounters any unspecified
      # item that was not preassigned and could not be set by a default.
      '-f -D',

      # Subsequent <key=value> command line parameters preassign item values
      # (just like an answers file). Some are for items that don't have
      # defaults and some are for items for which we don't want to use their
      # defaults.

      'cli::network::set_up_nic=false', # Do NOT mess with the network!
      "cli::network::interface=#{opts[:interface]}",
    ]

    # When relevant, set password (hashes) for passwords that must be
    # preassigned when queries are disabled.
    # - All hashes correspond to 'P@ssw0rdP@ssw0rd'
    # - Be sure to put <key=value> in single quotes to prevent any bash
    #   interpretation.
    config << "cli::simp::scenario=#{opts[:scenario]}" if opts[:scenario] != 'simp'
    if opts[:set_grub_password]
      config << "'grub::password=#{grub_pwd_hash}'"
    else
      config << 'cli::set_grub_password=false'
    end

    unless opts[:iso_install]
      if opts[:priv_user].nil?
        config << 'cli::ensure_priv_local_user=false'
      else
        if opts[:priv_user][:name] != 'simpadmin'
          config << "cli::local_priv_user=#{opts[:priv_user][:name]}"
        end

        unless opts[:priv_user][:exists]
          config << "'cli::local_priv_user_password=#{priv_user_pwd_hash}'"
        end
      end
    end

    if opts[:ldap_server]
      config << "'simp_openldap::server::conf::rootpw=#{ldap_rootpw_hash}'"
    else
      config << 'cli::is_simp_ldap_server=false'
    end

    unless opts[:use_simp_internet_repos]
      config << "cli::use_internet_simp_yum_repos=false"
    end

    unless opts[:logservers].empty?
      config << "simp_options::syslog::log_servers=#{opts[:logservers].join(',,')}"

      unless opts[:failover_logservers].empty?
        config << "simp_options::syslog::failover_log_servers=#{opts[:failover_logservers].join(',,')}"
      end
    end

    if (opts[:scenario] == 'poss') && !opts[:sssd]
      # only case in which would be prompted for use of sssd
      config << 'simp_options::sssd=false'
    end


    config += opts[:config_opts_to_add]
    config
  }

  let(:puppet_env_dir) { "/etc/puppetlabs/code/environments/#{opts[:puppet_env]}" }
  let(:secondary_env_dir) { "/var/simp/environments/#{opts[:puppet_env]}" }
  let(:os_release) { fact_on(host, 'operatingsystemmajrelease') }
  let(:fqdn) { fact_on(host, 'fqdn') }
  let(:domain) { fact_on(host, 'domain') }
  let(:fips) { fips_enabled(host) }
  let(:modules) { on(host, 'ls /usr/share/simp/modules').stdout.split("\n") }

  if opts[:priv_user] && !opts[:priv_user][:exists]
    it 'should ensure local priv user does not yet exist as a precondition' do
      on(host, "userdel -r #{opts[:priv_user][:name]}", :accept_all_exit_codes => true)
    end
  end

  it "should run `simp config` to configure server for bootstrap #{opts[:description]}" do
    result = on(host, "#{opts[:env_vars].join(' ')} simp config #{config_opts.join(' ')}")
  end

  it "should create the #{opts[:puppet_env]} Puppet environment" do
    expect( directory_exists_on(host, puppet_env_dir) ).to be true
  end

  it 'should create a pair of Puppetfiles configured for SIMP' do
    expect( file_exists_on(host, "#{puppet_env_dir}/Puppetfile") ).to be true
    on(host, "grep 'Puppetfile.simp' #{puppet_env_dir}/Puppetfile | grep ^instance_eval")

    expect( file_exists_on(host, "#{puppet_env_dir}/Puppetfile.simp") ).to be true
    modules.each do |name|
      result = on(host, "grep name /usr/share/simp/modules/#{name}/metadata.json | grep #{name}")
      repo_name = result.stdout.match( /(\w+\-\w*)/ )[1]
      on(host, "grep '/usr/share/simp/git/puppet_modules/#{repo_name}.git' #{puppet_env_dir}/Puppetfile.simp")
    end
  end

  it 'should create a environment.conf with secondary env in modulepath' do
    expect( file_exists_on(host, "#{puppet_env_dir}/environment.conf") ).to be true
    custom_mod_path = "modulepath = site:modules:/var/simp/environments/#{opts[:puppet_env]}/site_files:$basemodulepath"
    on(host, "grep '#{custom_mod_path}' #{puppet_env_dir}/environment.conf")
  end

  it 'should create a hiera.yaml.conf that matches enviroment-skeleton' do
    expect( file_exists_on(host, "#{puppet_env_dir}/hiera.yaml") ).to be true
    on(host, "diff /usr/share/simp/environment-skeleton/puppet/hiera.yaml #{puppet_env_dir}/hiera.yaml")
  end

  it 'should populate modules dir with modules from local git repos' do
    modules.each do |name|
      expect( directory_exists_on(host, "#{puppet_env_dir}/modules/#{name}") ).to be true
    end
  end

  it 'should create a simp_config_settings.yaml global hiera file' do
    yaml_file = "#{puppet_env_dir}/data/simp_config_settings.yaml"
    expect( file_exists_on(host, yaml_file) ).to be true

    actual = YAML.load( file_contents_on(host, yaml_file) )

    # any value that is 'SKIP' can vary based on virtual host or `simp config` run
    expected = {
      'chrony::servers'                  =>"%{alias('simp_options::ntp::servers')}",
      'simp::runlevel'                   => 3,
      'simp_options::dns::search'        => [ domain ],

      # Skip this because it is depends upon the host network
      'simp_options::dns::servers'        => 'SKIP',
      'simp_options::fips'                => fips,

      # Skip this because it is depends upon existing host ntp config
      'simp_options::ntp::servers'        => 'SKIP',
      'simp_options::puppet::ca'          => fqdn,
      'simp_options::puppet::ca_port'     => 8141,
      'simp_options::puppet::server'      => fqdn,
      'simp_options::syslog::log_servers' => opts[:logservers],

      # Skip this because it is depends upon the host network
      'simp_options::trusted_nets'        => 'SKIP',

      'useradd::securetty'                => []
    }

    # FIXME The grub password shouldn't be stored in global hieradata,
    # as it is not used by Puppet, yet. See SIMP-6527 and SIMP-9411.
    expected['grub::password'] = grub_pwd_hash if opts[:set_grub_password]

    if opts[:ldap_server]
      expected['simp_options::ldap']            = true
      expected['simp_options::ldap::base_dn']   = domain.split('.').map { |x| "dc=#{x}" }.join(',')
      expected['simp_options::ldap::bind_hash'] = 'SKIP'
      expected['simp_options::ldap::bind_pw']   = 'SKIP'
      expected['simp_options::ldap::sync_hash'] = 'SKIP'
      expected['simp_options::ldap::sync_pw']   = 'SKIP'
      expected['sssd::domains']                 = [ 'LDAP' ]
      expected['simp_options::sssd'] = true if (opts[:scenario] == 'poss')
    else
      include_sssd_domains = true
      if (opts[:scenario] == 'poss')
        if opts[:sssd]
          expected['simp_options::sssd'] = true
        else
          expected['simp_options::sssd'] = false
          include_sssd_domains = false
        end
      end

      if include_sssd_domains
        if os_release < '8'
          # can't be empty for EL7
          expected['sssd::domains'] = [ 'LOCAL' ]
        else
          expected['sssd::domains'] = []
        end
      end
    end

    if opts[:iso_install]
      expected['simp::classes'] = ['simp::yum::repo::local_os_updates', 'simp::yum::repo::local_simp']
      expected['simp::yum::repo::local_os_updates::servers'] = ["%{hiera('simp_options::puppet::server')}"]
      expected['simp::yum::repo::local_simp::servers'] = ["%{hiera('simp_options::puppet::server')}"]
    elsif opts[:use_simp_internet_repos]
      expected['simp::classes'] = ['simp::yum::repo::internet_simp']
    end

    unless opts[:logservers].empty?
     expected['simp_options::syslog::failover_log_servers'] = opts[:failover_logservers]
    end

    expected['svckill::mode'] = 'warning' if opts[:scenario] == 'simp'

    if actual.keys.sort != expected.keys.sort
      puts "actual = #{actual.keys.sort.to_yaml}"
      puts "expected = #{expected.keys.sort.to_yaml}"
    end

    expect( actual.keys.sort ).to eq(expected.keys.sort)
    normalized_exp = expected.delete_if { |key,value| value == 'SKIP' }
    normalized_exp['simp::classes'].sort!  if normalized_exp.key?('simp:classes')
    actual['simp::classes'].sort!  if actual.key?('simp:classes')
    normalized_exp.each do |key,value|
      expect( actual[key] ).to eq(value)
    end
  end

  it 'should create a <SIMP server fqdn>.yaml hiera file' do
    yaml_file = "#{puppet_env_dir}/data/hosts/#{fqdn}.yaml"
    actual = YAML.load( file_contents_on(host, yaml_file) )

    # load in template and then merge with adjustments that
    # `simp config` should make
    template = '/usr/share/simp/environment-skeleton/puppet/data/hosts/puppet.your.domain.yaml'
    expected = YAML.load( file_contents_on(host, template) )
    adjustments = {
      'puppetdb::master::config::puppetdb_server' => "%{hiera('simp_options::puppet::server')}",
      'puppetdb::master::config::puppetdb_port'   => 8139,
      'simp::server::classes'                     => [ 'simp::puppetdb' ]
    }

    if opts[:ldap_server]
      adjustments['simp_openldap::server::conf::rootpw'] = ldap_rootpw_hash
      adjustments['simp::server::classes'] << 'simp::server::ldap'
    end

    if opts[:iso_install]
      adjustments['simp::server::allow_simp_user'] = true
      adjustments['simp::yum::repo::local_os_updates::enable_repo'] = false
      adjustments['simp::yum::repo::local_simp::enable_repo'] = false
      adjustments['simp::server::classes'] << 'simp::server::yum'
    else
      adjustments['simp::server::allow_simp_user'] = false
      if opts[:priv_user]
        adjustments['pam::access::users'] = {
          opts[:priv_user][:name] => { 'origins' => [ 'ALL' ] }
        }

        adjustments['selinux::login_resources'] = {
          opts[:priv_user][:name] => { 'seuser' => 'staff_u', 'mls_range' => 's0-s0:c0.c1023' }
        }

        adjustments['sudo::user_specifications'] = {
          "#{opts[:priv_user][:name]}_su" => {
            'user_list' => [ opts[:priv_user][:name] ],
            'cmnd'      => [ 'ALL' ],
            'passwd'    => !opts[:priv_user][:has_keys],
            'options'   => { 'role' => 'unconfined_r' }
          }
        }
      end
    end

    expected.merge!(adjustments)
    expected['simp::server::classes'].sort!
    actual['simp::server::classes'].sort! if actual.key?('simp::server::classes')
    expect( actual ).to eq(expected)
  end

  it "should set $simp_scenario to #{opts[:scenario]} in site.pp" do
    site_pp = File.join(puppet_env_dir, 'manifests', 'site.pp')
    expect( file_exists_on(host, site_pp) ).to be true
    actual = file_contents_on(host, site_pp)
    expect( actual ).to match(/^\$simp_scenario\s*=\s*'#{opts[:scenario]}'/)
  end

  it "should create a #{opts[:puppet_env]} secondary environment" do
    expect( directory_exists_on(host, secondary_env_dir) ).to be true
    expect( directory_exists_on(host, "#{secondary_env_dir}/FakeCA") ).to be true
    expect( directory_exists_on(host, "#{secondary_env_dir}/rsync") ).to be true
    expect( directory_exists_on(host, "#{secondary_env_dir}/site_files") ).to be true
  end

  it 'should create cacerts and host cert files in the secondary env' do
    keydist_dir = "#{secondary_env_dir}/site_files/pki_files/files/keydist"
    on(host, "ls #{keydist_dir}/cacerts/cacert_*.pem")
    on(host, "ls #{keydist_dir}/#{fqdn}/#{fqdn}.pem")
    on(host, "ls #{keydist_dir}/#{fqdn}/#{fqdn}.pub")
  end

  it 'should minimally configure Puppet' do
    expected_keylength = fips ? '2048' : '4096'
    expect( on(host, 'puppet config print keylength').stdout.strip ).to eq(expected_keylength)
    expect( on(host, 'puppet config print server').stdout.strip ).to eq(fqdn)
    expect( on(host, 'puppet config print ca_server').stdout.strip ).to eq(fqdn)
    expect( on(host, 'puppet config print ca_port').stdout.strip ).to eq('8141')

    autosign_conf = on(host, 'puppet config print autosign').stdout.strip
    actual = file_contents_on(host, autosign_conf)
    expect( actual ).to match(%r(^#{fqdn}$))
  end

  if opts[:priv_user] && !opts[:priv_user][:exists]
    it "should create privileged user '#{opts[:priv_user][:name]}'" do
      username = opts[:priv_user][:name]
      on(host, "grep #{username} /etc/passwd")
      on(host, "grep #{username} /etc/group")
      expect( directory_exists_on(host, "/var/local/#{username}") ).to be true
    end

    it "should be able to login via ssh as '#{opts[:priv_user][:name]}' using password" do
      on(host, 'puppet resource package expect ensure=present')
      on(host, 'mkdir -p /root/scripts')
      script = '/root/scripts/ssh_cmd_script'
      scp_to(host, File.join(files_dir, 'ssh_cmd_script'), script)
      on(host, "chmod +x #{script}")
      on(host, "#{script} #{opts[:priv_user][:name]} #{host.name} #{password} date")
    end
  end

  if opts[:priv_user] && opts[:priv_user][:has_keys]
    it "should copy privileged user '#{opts[:priv_user][:name]}' keys to /etc/ssh/local_keys" do
      keys_file = "/etc/ssh/local_keys/#{opts[:priv_user][:name]}"
      expect( file_exists_on(host, keys_file) ).to be true
    end
  end

  it 'should ensure puppet server entry is in /etc/hosts' do
    actual = file_contents_on(host, '/etc/hosts')
    ip = fact_on(host, "ipaddress_#{opts[:interface]}")
    expected = <<~EOM
      127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4
      ::1 localhost localhost.localdomain localhost6 localhost6.localdomain6
      #{ip} #{fqdn} #{fqdn.split('.').first}
    EOM
  end

  if opts[:set_grub_password]
    # This will be replaced with using the simp_grub Puppet module, so may not
    # be worth expending effort to test now
    it 'should set grub password'
  end
end
