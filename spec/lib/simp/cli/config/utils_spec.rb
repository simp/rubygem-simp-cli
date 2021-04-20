require 'simp/cli/config/utils'
require 'rspec/its'
require 'spec_helper'

describe Simp::Cli::Config::Utils do

  describe '.validate_domain' do
    it 'validates good domains' do
      expect( Simp::Cli::Config::Utils.validate_domain 'test.com').to eq true
      expect( Simp::Cli::Config::Utils.validate_domain 'test').to eq true
      expect( Simp::Cli::Config::Utils.validate_domain 't').to eq true
      expect( Simp::Cli::Config::Utils.validate_domain '0.t-t.0.t').to eq true
      expect( Simp::Cli::Config::Utils.validate_domain '0-0').to eq true
      expect( Simp::Cli::Config::Utils.validate_domain '0-0.0-0.0-0').to eq true
      expect( Simp::Cli::Config::Utils.validate_domain '0f').to eq true
      expect( Simp::Cli::Config::Utils.validate_domain 'f0').to eq true
      expect( Simp::Cli::Config::Utils.validate_domain 'test.00f').to eq true
      expect( Simp::Cli::Config::Utils.validate_domain 't.').to eq true
      expect( Simp::Cli::Config::Utils.validate_domain 'test.com.').to eq true
    end

    it "doesn't validate bad domains" do
      expect( Simp::Cli::Config::Utils.validate_domain '-test').to be false
      expect( Simp::Cli::Config::Utils.validate_domain 'test-').to be false
      expect( Simp::Cli::Config::Utils.validate_domain 'test-.test').to be false
      expect( Simp::Cli::Config::Utils.validate_domain 'test.-test').to be false
      expect( Simp::Cli::Config::Utils.validate_domain '0').to be false
      expect( Simp::Cli::Config::Utils.validate_domain '0212').to be false
      expect( Simp::Cli::Config::Utils.validate_domain 'test.0').to be false
      expect( Simp::Cli::Config::Utils.validate_domain 't.t.t.t.0').to be false
      expect( Simp::Cli::Config::Utils.validate_domain 'an-extremely-long-dns-label-that-is-just-over-63-characters-long.test').to be false
      expect( Simp::Cli::Config::Utils.validate_domain 'test.an-extremely-long-dns-label-that-is-just-over-63-characters-long').to be false
      expect( Simp::Cli::Config::Utils.validate_domain 'test.an-extremely-long-dns-label-that-is-just-over-63-characters-long.test').to be false
      expect( Simp::Cli::Config::Utils.validate_domain 'an-extremely-long-dns-label-that-is-just-over-63-characters-long.').to be false
      expect( Simp::Cli::Config::Utils.validate_domain '.').to be false
    end
  end

  describe '.validate_fqdn' do
    it 'validates good FQDNs' do
      expect( Simp::Cli::Config::Utils.validate_fqdn 'simp.dev' ).to eq true
      expect( Simp::Cli::Config::Utils.validate_fqdn 'si-mp.dev' ).to eq true

      # oddly enough, ending with a '.' is actually valid
      expect( Simp::Cli::Config::Utils.validate_fqdn 'simp.dev.' ).to eq true

      # RFC 1123 permits hostname labels to start with digits (overriding RFC 952)
      expect( Simp::Cli::Config::Utils.validate_fqdn '0simp.dev' ).to eq true

      # complex domain from an AWS host
      expect( Simp::Cli::Config::Utils.validate_fqdn 'xyz-w-puppet.qrst-a1-b2' ).to eq true

      # long multi-part domain
      expect( Simp::Cli::Config::Utils.validate_fqdn 'xyz.w.puppet.qrst.a1.b2.' ).to eq true
    end

    it "doesn't validate bad FQDNs" do
      expect( Simp::Cli::Config::Utils.validate_fqdn 'localhost' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn 'a' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn 'my_domain.com' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn '0.0.0' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn '0.0.0.0' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn '1.2.3.4' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn '.simp.dev' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn '-simp.dev' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn 'simp.dev-' ).to eq false
    end
  end


  describe '.validate_ip' do
    it 'validates good IPs' do
      expect( Simp::Cli::Config::Utils.validate_ip '192.168.1.1' ).to eq true
    end

    it "doesn't validate bad IPS" do
      expect( Simp::Cli::Config::Utils.validate_ip 0 ).to            eq false
      expect( Simp::Cli::Config::Utils.validate_ip false ).to        eq false
      expect( Simp::Cli::Config::Utils.validate_ip nil ).to          eq false
      expect( Simp::Cli::Config::Utils.validate_ip 'zombo.com' ).to  eq false
      expect( Simp::Cli::Config::Utils.validate_ip '1.2.3' ).to      eq false
      expect( Simp::Cli::Config::Utils.validate_ip '1.2.3.999' ).to  eq false
      expect( Simp::Cli::Config::Utils.validate_ip '8.8.8.8.' ).to   eq false
      expect( Simp::Cli::Config::Utils.validate_ip '1.2.3.4.5' ).to  eq false
      expect( Simp::Cli::Config::Utils.validate_ip '1.2.3.4/24' ).to eq false
    end
  end


  describe '.validate_hostname' do
    it 'validates good hostnames' do
      expect( Simp::Cli::Config::Utils.validate_hostname 'log' ).to        eq true
      expect( Simp::Cli::Config::Utils.validate_hostname 'log-server' ).to eq true

      # RFC 1123 permits hostname labels to start with digits (overriding RFC 952)
      expect( Simp::Cli::Config::Utils.validate_hostname '0log' ).to eq true
    end

    it "doesn't validate bad hostnames" do
      expect( Simp::Cli::Config::Utils.validate_hostname 'log-' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_hostname 'log.' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_hostname '-log' ).to eq false

      # longer than 63 chars
      expect( Simp::Cli::Config::Utils.validate_hostname \
            'log0234567891234567890223456789323456789423456789523456789623459'
      ).to eq false
    end
  end


  describe '.validate_hiera_lookup' do
    it 'validates correct hiera lookup syntax' do
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup "%{hiera('puppet::ca')}" ).to eq true
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup '%{::domain}' ).to eq true
    end

    it 'validates correct hiera lookup syntax' do
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup "%[hiera('puppet::ca')]" ).to eq false
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup '' ).to    eq false
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup 'foo' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup nil).to    eq false
    end
  end


  describe '.encrypt_password_sha512' do
    it 'encrypts a known password and salt to the correct SHA-512 password hash' do
      expect( Simp::Cli::Config::Utils.encrypt_password_sha512('foo', 'somesalt')
      ).to eq '$6$somesalt$xK8qDo8XIAgPi.kqwyaXRXvyb6kUTZGisSL7HFiC4pQ7OEvk70x9v9P8dKjWsUni6qJT44R7rbx3YDQBT6ho50'
    end
  end

  describe '.validate_password_sha512' do
    it 'validates a correct SHA-512 password hash' do
      expect( Simp::Cli::Config::Utils.validate_password_sha512  \
        '$6$somesalt$xK8qDo8XIAgPi.kqwyaXRXvyb6kUTZGisSL7HFiC4pQ7OEvk70x9v9P8dKjWsUni6qJT44R7rbx3YDQBT6ho50'
      ).to eq true
    end

    it 'fails to validate a MD5 password hash' do
      expect( Simp::Cli::Config::Utils.validate_password_sha512  \
        "$1$somesalt$AvTfS5Nt2nHGq9KNvsZIW/"
      ).to eq false
    end

  end


  describe '.encrypt_openldap_hash' do
    it 'encrypts a known password and salt to the correct SHA-1 password hash' do
      expect( Simp::Cli::Config::Utils.encrypt_openldap_hash \
        'foo', "\xef\xb2\x2e\xac"
      ).to eq '{SSHA}zxOLQEdncCJTMObl5s+y1N/Ydh3vsi6s'
    end
  end


  describe '.validate_openldap_hash' do
    it 'validates OpenLDAP-format SHA-1 algorithm (FIPS 160-1) password hash' do
      expect( Simp::Cli::Config::Utils.validate_openldap_hash  \
        '{SSHA}Y6x92VpatHf9G6yMiktUYTrA/3SxUFm'
      ).to eq true
    end

    it 'fails to validate OpenLDAP-format MD5 algorithm password hash' do
      expect( Simp::Cli::Config::Utils.validate_openldap_hash  \
        '{CRYPT}Y6x92VpatHf9G6yMiktUYTrA/3SxUFm'
      ).to eq false
    end
  end


  describe '.check_openldap_password' do
    it 'validates a valid password against an OpenLDAP-format SHA-1 hash' do
      expect( Simp::Cli::Config::Utils.check_openldap_password('foo',
        '{SSHA}zxOLQEdncCJTMObl5s+y1N/Ydh3vsi6s')
      ).to be true
    end

    it 'fails to validate an invalid password against an OpenLDAP-format SHA-1 hash' do
      expect( Simp::Cli::Config::Utils.check_openldap_password('bar',
        '{SSHA}zxOLQEdncCJTMObl5s+y1N/Ydh3vsi6s')
      ).to be false
    end
  end
end
