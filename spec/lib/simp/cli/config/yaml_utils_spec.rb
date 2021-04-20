require 'simp/cli/config/yaml_utils'
require 'tmpdir'

class YamlUtilsTester
  include Simp::Cli::Config::YamlUtils
end

describe 'Simp::Cli::Config::YamlUtils API' do
  before :each do
    @files_dir = File.join( File.dirname(__FILE__), 'files', 'yaml_utils' )
    @tmp_dir   = Dir.mktmpdir( File.basename(__FILE__) )
    @test_file = File.join(@tmp_dir, 'test.yaml')
    @tester = YamlUtilsTester.new
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe '#merge_required?' do
    it 'returns false when either argument is not an Array or Hash' do
      expect( @tester.merge_required?(false, {}) ).to be false
      expect( @tester.merge_required?(nil, {}) ).to be false
      expect( @tester.merge_required?([], 1) ).to be false
      expect( @tester.merge_required?([], nil) ).to be false
    end

    it 'returns false when arguments are not both either Arrays or Hashes' do
      expect( @tester.merge_required?([],{}) ).to be false
      expect( @tester.merge_required?({},[]) ).to be false
    end

    it 'returns true when new Array has elements not found in old Array' do
      expect( @tester.merge_required?([1, 2, 3], [1, 4, 5]) ).to be true
      expect( @tester.merge_required?([], [1, 4, 5]) ).to be true
    end

    it 'returns false when new Array does not new elements' do
      expect( @tester.merge_required?([1, 2, 3], [1]) ).to be false
      expect( @tester.merge_required?([1, 2, 3], []) ).to be false
    end

    it 'returns true when new Hash has a new primary key' do
      old = { 'a' => 1, 'b' => { 'c' => 2 } }
      new = { 'd' => 3 }
      expect( @tester.merge_required?(old, new) ).to be true
    end

    it 'returns true when new Hash has a changed value for same primary key' do
      old = { 'a' => 1, 'b' => { 'c' => 2 } }
      new = { 'b' => 10 }
      expect( @tester.merge_required?(old, new) ).to be true
    end

    it 'returns false when new Hash matches old Hash' do
      old = { 'a' => 1, 'b' => { 'c' => 2 } }
      expect( @tester.merge_required?(old, old) ).to be false
    end

    it 'returns false when new Hash has a key whose value matches old Hash' do
      old = { 'a' => 1, 'b' => { 'c' => 2 } }
      new = { 'b' => { 'c' => 2 } }
      expect( @tester.merge_required?(old, new) ).to be false
    end
  end

  describe '#pair_to_yaml_tag' do
    {
      'nil'            => { :value => nil, :exp => "key: \n" },
      'boolean'        => { :value => true, :exp => "key: true\n" },
      'integer'        => { :value => 1, :exp => "key: 1\n" },
      'float'          => { :value => 1.5, :exp => "key: 1.5\n" },
      'simple string'  => { :value => 'simple', :exp => "key: simple\n" },
      'complex string' => { :value => "%{alias('simp_options::trusted_nets')}",
        :exp => "key: \"%{alias('simp_options::trusted_nets')}\"\n" },
      'array'          => { :value => [1,2], :exp => <<~EOM
        key:
        - 1
        - 2
      EOM
      },
      'hash'           => { :value => {'a' => {'b' => [1,2]}}, :exp => <<~EOM
        key:
          a:
            b:
            - 1
            - 2
        EOM
      }
    }.each do |type, attr|
      it "returns a valid YAML tag for a #{type} value" do
        expect( @tester.pair_to_yaml_tag('key', attr[:value]) ).to eq(attr[:exp])
      end
    end
  end

  describe '#load_yaml_with_comment_blocks' do
    it 'should load YAML and comment blocks before primary keys' do
      file = File.join(@files_dir, 'base.yaml')
      result = @tester.load_yaml_with_comment_blocks(file)
      expected = {
        :filename => file,
        :preamble => ['# YAML example to exercise Simp::Cli::Config::YamlUtils'],
        :content => {
          'simp_apache::conf::ssl::trusted_nets' => {
            :comments => ['# simp_apache::conf::ssl::trusted_nets description' ],
            :value    => "%{alias('simp_options::trusted_nets')}"
          },
          'simp::yum::repo::local_os_updates::enable_repo' => {
            :comments => [
              '',
              '# uncomment out to enable',
              "#simp_apache::ssl::sslverifyclient: 'none'",
              '',
              '# unnecessary quotes around the key'
            ],
            :value    => false
          },
          'simp::yum::repo::local_simp::enable_repo' => {
            :comments => [],
            :value    => false
          },
          'pam::access::users' => {
            :comments => [
              '',
              '# complex hash with unnecessary quotes around one of the values',
            ],
            :value   => {
              'local_admin1' => {
                'origins' => [ 'ALL' ]
              },
              'local_admin2' => {
                'origins' => [ 'ALL' ]
              }
            }
          },
          'simp::classes' => {
            :comments => [
              '',
              '# array with unnecessary quotes around one of the values'
            ],
            :value   => ['simp::server','simp::server::ldap']
          },
          'simp::server::classes' => {
            :comments => [ '' ],
            :value   => ['simp::puppetdb']
          }
        }
      }

      expect( result ).to eq(expected)
    end
  end

  describe '#add_yaml_tag_directive' do
    it 'should add the YAML tag to the end of the file when no regex specified' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      @tester.add_yaml_tag_directive("\nnew: tag", file_info)
      expected = File.join(@files_dir, 'base_tag_appended.yaml')
      expect( IO.read(@test_file) ).to eq IO.read(expected)
    end

    it 'should insert the YAML tag before the key matching regex' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      @tester.add_yaml_tag_directive("\nnew: tag", file_info, /^pam::access::users$/ )
      expected = File.join(@files_dir, 'base_tag_inserted.yaml')
      expect( IO.read(@test_file) ).to eq IO.read(expected)
    end

    it 'should add the YAML tag to the end of the file when regex does not match any key' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      @tester.add_yaml_tag_directive("\nnew: tag", file_info, /^does::not::exist$/ )
      expected = File.join(@files_dir, 'base_tag_appended.yaml')
      expect( IO.read(@test_file) ).to eq IO.read(expected)
    end
  end

  describe '#replace_yaml_tag' do
    it 'should replace the YAML tag with the new simple value' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      @tester.replace_yaml_tag('simp::yum::repo::local_simp::enable_repo', true, file_info)
      expected = File.join(@files_dir, 'base_simple_replace.yaml')
      expect( IO.read(@test_file) ).to eq IO.read(expected)
      YAML.load(IO.read(@test_file)) # verifies modified file is still valid YAML
    end

    it 'should replace the YAML tag with the new Array value' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      @tester.replace_yaml_tag('simp::server::classes', ['site::puppetdb'], file_info)
      expected = File.join(@files_dir, 'base_array_replace.yaml')
      expect( IO.read(@test_file) ).to eq IO.read(expected)
      YAML.load(IO.read(@test_file)) # verifies modified file is still valid YAML
    end

    it 'should replace the YAML tag with the new Hash value' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      new_hash = { 'simpadmin' => { 'origins' => [ 'ALL' ] } }
      @tester.replace_yaml_tag('pam::access::users', new_hash, file_info)
      expected = File.join(@files_dir, 'base_hash_replace.yaml')
      expect( IO.read(@test_file) ).to eq IO.read(expected)
      YAML.load(IO.read(@test_file)) # verifies modified file is still valid YAML
    end

    it 'should not modify the file when the specified key does not exist' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      @tester.replace_yaml_tag('does:not:exist', 'in file', file_info)
      expect( IO.read(@test_file) ).to eq IO.read(file)
    end
  end

  describe '#merge_yaml_tag' do
    it 'merges Array values' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      @tester.merge_yaml_tag('simp::server::classes', ['simp::puppetdb', 'site::class1'], file_info)
      expected = File.join(@files_dir, 'base_array_merge.yaml')
      expect( IO.read(@test_file) ).to eq IO.read(expected)
      YAML.load(IO.read(@test_file)) # verifies modified file is still valid YAML
    end

    it 'inserts new keys into existing Hash' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      new_hash = {
        'local_admin1' => { 'origins' => [ 'ALL' ] },
        'simpadmin' => { 'origins' => [ 'ALL' ] }
      }
      @tester.merge_yaml_tag('pam::access::users', new_hash, file_info)
      expected = File.join(@files_dir, 'base_hash_merge_insert_key.yaml')
      expect( IO.read(@test_file) ).to eq IO.read(expected)
      YAML.load(IO.read(@test_file)) # verifies modified file is still valid YAML
    end

    it 'replaces values of existing Hash keys' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      new_hash = { 'local_admin2' => { 'origins' => [ '10.0.2.0/24' ] } }
      @tester.merge_yaml_tag('pam::access::users', new_hash, file_info)
      expected = File.join(@files_dir, 'base_hash_merge_replace_value.yaml')
      expect( IO.read(@test_file) ).to eq IO.read(expected)
      YAML.load(IO.read(@test_file)) # verifies modified file is still valid YAML
    end

    it 'fails when the new value is not an Array or a Hash' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      #@tester.merge_yaml_tag('pam::access::users', new_hash, file_info)
    end

    it 'fails when tag directive for key is not present in file' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      expect{ @tester.merge_yaml_tag('does::not::exist', 'in file', file_info) }
        .to raise_error(%r(does::not::exist does not exist in #{@test_file}))
    end

    it 'fails when the new and old value are not both Hashes or Arrays' do
      file = File.join(@files_dir, 'base.yaml')
      FileUtils.cp(file, @test_file)
      file_info = @tester.load_yaml_with_comment_blocks(@test_file)

      expect{ @tester.merge_yaml_tag('simp::yum::repo::local_simp::enable_repo', ['simp'], file_info) }
        .to raise_error(/Unable to merge values for simp::yum::repo::local_simp::enable_repo/)
    end
  end

  describe '#merge_or_replace_yaml_tag' do
    context 'default behavior' do
      it 'leaves file untouched and returns :none when tag directive for key is not present in file' do
        file = File.join(@files_dir, 'base.yaml')
        FileUtils.cp(file, @test_file)
        file_info = @tester.load_yaml_with_comment_blocks(@test_file)

        result = @tester.merge_or_replace_yaml_tag('does:not:exist', 'in file', file_info)
        expect( result ).to eq :none
        expect( IO.read(@test_file) ).to eq IO.read(file)
      end

      it 'leaves file untouched and returns :none when no changes are required' do
        file = File.join(@files_dir, 'base.yaml')
        FileUtils.cp(file, @test_file)
        file_info = @tester.load_yaml_with_comment_blocks(@test_file)

        result = @tester.merge_or_replace_yaml_tag(
          'simp::yum::repo::local_simp::enable_repo', false, file_info)
        expect( result ).to eq :none
        expect( IO.read(@test_file) ).to eq IO.read(file)
      end

      it 'replaces the tag directive and returns :replace when new value is nil' do
        file = File.join(@files_dir, 'base.yaml')
        FileUtils.cp(file, @test_file)
        file_info = @tester.load_yaml_with_comment_blocks(@test_file)

        result = @tester.merge_or_replace_yaml_tag('pam::access::users', nil, file_info)
        expect( result ).to eq :replace
        expected = File.join(@files_dir, 'base_nil_replace.yaml')
        expect( IO.read(@test_file) ).to eq IO.read(expected)
        YAML.load(IO.read(@test_file)) # verifies modified file is still valid YAML
      end

      it 'replaces the tag directive and returns :replace when new value is not nil' do
        file = File.join(@files_dir, 'base.yaml')
        FileUtils.cp(file, @test_file)
        file_info = @tester.load_yaml_with_comment_blocks(@test_file)

        result = @tester.merge_or_replace_yaml_tag(
          'simp::server::classes', ['site::puppetdb'], file_info)
        expect( result ).to eq :replace
        expected = File.join(@files_dir, 'base_array_replace.yaml')
        expect( IO.read(@test_file) ).to eq IO.read(expected)
        YAML.load(IO.read(@test_file)) # verifies modified file is still valid YAML
      end
    end

    context 'merge=true' do
      it 'replaces the tag directive and returns :replace when value types do not match' do
        file = File.join(@files_dir, 'base.yaml')
        FileUtils.cp(file, @test_file)
        file_info = @tester.load_yaml_with_comment_blocks(@test_file)

        result = @tester.merge_or_replace_yaml_tag(
          'simp_apache::conf::ssl::trusted_nets', ['10.0.2.0/24'], file_info, true)
        expect( result ).to eq :replace
        expected = File.join(@files_dir, 'base_replace_type_change.yaml')
        expect( IO.read(@test_file) ).to eq IO.read(expected)
        YAML.load(IO.read(@test_file)) # verifies modified file is still valid YAML
      end

      it 'merges the values and returns :merge when new value can be merged' do
        file = File.join(@files_dir, 'base.yaml')
        FileUtils.cp(file, @test_file)
        file_info = @tester.load_yaml_with_comment_blocks(@test_file)

        result = @tester.merge_or_replace_yaml_tag(
          'simp::server::classes', ['simp::puppetdb', 'site::class1'], file_info, true)
        expect( result ).to eq :merge
        expected = File.join(@files_dir, 'base_array_merge.yaml')
        expect( IO.read(@test_file) ).to eq IO.read(expected)
        YAML.load(IO.read(@test_file)) # verifies modified file is still valid YAML
      end

      it 'leaves file untouched and returns :none when new value contained in old value' do
        file = File.join(@files_dir, 'base.yaml')
        FileUtils.cp(file, @test_file)
        file_info = @tester.load_yaml_with_comment_blocks(@test_file)

        result = @tester.merge_or_replace_yaml_tag(
          'simp::classes', ['simp::server'], file_info, true)
        expect( result ).to eq :none
        expect( IO.read(@test_file) ).to eq IO.read(file)
      end
    end
  end
end
