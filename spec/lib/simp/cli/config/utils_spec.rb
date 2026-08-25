# frozen_string_literal: true

require 'simp/cli/config/utils'
require 'rspec/its'
require 'spec_helper'

describe Simp::Cli::Config::Utils do
  describe '.validate_domain' do
    it 'validates good domains' do
      expect(described_class.validate_domain('test.com')).to be true
      expect(described_class.validate_domain('test')).to be true
      expect(described_class.validate_domain('t')).to be true
      expect(described_class.validate_domain('0.t-t.0.t')).to be true
      expect(described_class.validate_domain('0-0')).to be true
      expect(described_class.validate_domain('0-0.0-0.0-0')).to be true
      expect(described_class.validate_domain('0f')).to be true
      expect(described_class.validate_domain('f0')).to be true
      expect(described_class.validate_domain('test.00f')).to be true
      expect(described_class.validate_domain('t.')).to be true
      expect(described_class.validate_domain('test.com.')).to be true
    end

    it "doesn't validate bad domains" do
      expect(described_class.validate_domain('-test')).to be false
      expect(described_class.validate_domain('test-')).to be false
      expect(described_class.validate_domain('test-.test')).to be false
      expect(described_class.validate_domain('test.-test')).to be false
      expect(described_class.validate_domain('0')).to be false
      expect(described_class.validate_domain('0212')).to be false
      expect(described_class.validate_domain('test.0')).to be false
      expect(described_class.validate_domain('t.t.t.t.0')).to be false
      expect(described_class.validate_domain('an-extremely-long-dns-label-that-is-just-over-63-characters-long.test')).to be false
      expect(described_class.validate_domain('test.an-extremely-long-dns-label-that-is-just-over-63-characters-long')).to be false
      expect(described_class.validate_domain('test.an-extremely-long-dns-label-that-is-just-over-63-characters-long.test')).to be false
      expect(described_class.validate_domain('an-extremely-long-dns-label-that-is-just-over-63-characters-long.')).to be false
      expect(described_class.validate_domain('.')).to be false
    end
  end

  describe '.validate_fqdn' do
    it 'validates good FQDNs' do
      expect(described_class.validate_fqdn('simp.dev')).to be true
      expect(described_class.validate_fqdn('si-mp.dev')).to be true

      # oddly enough, ending with a '.' is actually valid
      expect(described_class.validate_fqdn('simp.dev.')).to be true

      # RFC 1123 permits hostname labels to start with digits (overriding RFC 952)
      expect(described_class.validate_fqdn('0simp.dev')).to be true

      # complex domain from an AWS host
      expect(described_class.validate_fqdn('xyz-w-puppet.qrst-a1-b2')).to be true

      # long multi-part domain
      expect(described_class.validate_fqdn('xyz.w.puppet.qrst.a1.b2.')).to be true
    end

    it "doesn't validate bad FQDNs" do
      expect(described_class.validate_fqdn('localhost')).to be false
      expect(described_class.validate_fqdn('a')).to be false
      expect(described_class.validate_fqdn('my_domain.com')).to be false
      expect(described_class.validate_fqdn('0.0.0')).to be false
      expect(described_class.validate_fqdn('0.0.0.0')).to be false
      expect(described_class.validate_fqdn('1.2.3.4')).to be false
      expect(described_class.validate_fqdn('.simp.dev')).to be false
      expect(described_class.validate_fqdn('-simp.dev')).to be false
      expect(described_class.validate_fqdn('simp.dev-')).to be false
    end
  end

  describe '.validate_ip' do
    it 'validates good IPs' do
      expect(described_class.validate_ip('192.168.1.1')).to be true
    end

    it "doesn't validate bad IPS" do
      expect(described_class.validate_ip(0)).to            be false
      expect(described_class.validate_ip(false)).to        be false
      expect(described_class.validate_ip(nil)).to          be false
      expect(described_class.validate_ip('zombo.com')).to  be false
      expect(described_class.validate_ip('1.2.3')).to      be false
      expect(described_class.validate_ip('1.2.3.999')).to  be false
      expect(described_class.validate_ip('8.8.8.8.')).to   be false
      expect(described_class.validate_ip('1.2.3.4.5')).to  be false
      expect(described_class.validate_ip('1.2.3.4/24')).to be false
    end
  end

  describe '.validate_hostname' do
    it 'validates good hostnames' do
      expect(described_class.validate_hostname('log')).to        be true
      expect(described_class.validate_hostname('log-server')).to be true

      # RFC 1123 permits hostname labels to start with digits (overriding RFC 952)
      expect(described_class.validate_hostname('0log')).to be true
    end

    it "doesn't validate bad hostnames" do
      expect(described_class.validate_hostname('log-')).to be false
      expect(described_class.validate_hostname('log.')).to be false
      expect(described_class.validate_hostname('-log')).to be false

      # longer than 63 chars
      expect(described_class.validate_hostname('log0234567891234567890223456789323456789423456789523456789623459')).to be false
    end
  end

  describe '.validate_hiera_lookup' do
    it 'validates correct hiera lookup syntax' do
      expect(described_class.validate_hiera_lookup("%{hiera('puppet::ca')}")).to be true
      expect(described_class.validate_hiera_lookup('%{::domain}')).to be true
    end

    it 'rejects incorrect hiera lookup syntax' do
      expect(described_class.validate_hiera_lookup("%[hiera('puppet::ca')]")).to be false
      expect(described_class.validate_hiera_lookup('')).to    be false
      expect(described_class.validate_hiera_lookup('foo')).to be false
      expect(described_class.validate_hiera_lookup(nil)).to be false
    end
  end

  describe '.encrypt_password_sha512' do
    it 'encrypts a known password and salt to the correct SHA-512 password hash' do
      expect(described_class.encrypt_password_sha512('foo', 'somesalt')).to eq '$6$somesalt$xK8qDo8XIAgPi.kqwyaXRXvyb6kUTZGisSL7HFiC4pQ7OEvk70x9v9P8dKjWsUni6qJT44R7rbx3YDQBT6ho50'
    end
  end

  describe '.validate_password_sha512' do
    it 'validates a correct SHA-512 password hash' do
      expect(described_class.validate_password_sha512('$6$somesalt$xK8qDo8XIAgPi.kqwyaXRXvyb6kUTZGisSL7HFiC4pQ7OEvk70x9v9P8dKjWsUni6qJT44R7rbx3YDQBT6ho50')).to be true
    end

    it 'fails to validate a MD5 password hash' do
      expect(described_class.validate_password_sha512('$1$somesalt$AvTfS5Nt2nHGq9KNvsZIW/')).to be false
    end
  end

  describe '.encrypt_openldap_hash' do
    it 'encrypts a known password and salt to the correct SHA-1 password hash' do
      expect(described_class.encrypt_openldap_hash('foo', "\xef\xb2\x2e\xac")).to eq '{SSHA}zxOLQEdncCJTMObl5s+y1N/Ydh3vsi6s'
    end
  end

  describe '.validate_openldap_hash' do
    it 'validates OpenLDAP-format SHA-1 algorithm (FIPS 160-1) password hash' do
      expect(described_class.validate_openldap_hash('{SSHA}Y6x92VpatHf9G6yMiktUYTrA/3SxUFm')).to be true
    end

    it 'fails to validate OpenLDAP-format MD5 algorithm password hash' do
      expect(described_class.validate_openldap_hash('{CRYPT}Y6x92VpatHf9G6yMiktUYTrA/3SxUFm')).to be false
    end
  end

  describe '.check_openldap_password' do
    it 'validates a valid password against an OpenLDAP-format SHA-1 hash' do
      expect(described_class.check_openldap_password('foo',
                                                     '{SSHA}zxOLQEdncCJTMObl5s+y1N/Ydh3vsi6s')).to be true
    end

    it 'fails to validate an invalid password against an OpenLDAP-format SHA-1 hash' do
      expect(described_class.check_openldap_password('bar',
                                                     '{SSHA}zxOLQEdncCJTMObl5s+y1N/Ydh3vsi6s')).to be false
    end
  end

  describe '#validate_username' do
    it 'validates valid usernames' do
      expect(described_class.validate_username('admin')).to be true
      expect(described_class.validate_username('user_admin1')).to be true
      expect(described_class.validate_username('user3-special')).to be true
      expect(described_class.validate_username('_admin$')).to be true
    end

    it "doesn't validate invalid usernames" do
      expect(described_class.validate_username('1admin')).to be false
      expect(described_class.validate_username('Admin')).to be false
      expect(described_class.validate_username('this_is_longer_than_32_characters')).to be false
    end
  end
end
