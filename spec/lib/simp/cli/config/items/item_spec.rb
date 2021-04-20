require 'simp/cli/config/items/item'
require_relative 'spec_helper'

describe Simp::Cli::Config::Item do
  before :each do
    @ci = Simp::Cli::Config::Item.new
  end

  describe '#initialize' do
    it 'has no value when initialized' do
      expect( @ci.value ).to be_nil
    end

    it 'has nil os_value when initialized' do
      expect( @ci.os_value ).to be_nil
    end

    it 'has nil recommended_value when initialized' do
      expect( @ci.recommended_value ).to be_nil
    end

  end

  describe '#to_yaml_s' do
    it 'raises a Simp::Cli::Config::InternalError if @key is empty' do
      expect{ @ci.to_yaml_s }.to raise_error( Simp::Cli::Config::InternalError,
        /@key is empty for Simp::Cli::Config::Item/ )
    end

    it 'uses FIXME message as description if description is not set' do
      ci = TestItem.new
      ci.key = 'mykey'
      expect( ci.to_yaml_s ).to match(/FIXME/)
    end

    it 'returns nil instead of YAML key/value if @skip_yaml=true' do
      ci = TestItem.new
      ci.key = 'mykey'
      ci.value = 'myvalue'
      ci.skip_yaml = true
      expect( ci.to_yaml_s ).to eq(nil)
    end
  end

  describe '#print_summary' do
    it 'raises Simp::Cli::Config::InternalError on nil @key' do
      expect{ @ci.print_summary }.to raise_error( Simp::Cli::Config::InternalError,
        /@key is empty for Simp::Cli::Config::Item/ )
    end

    it 'raises a Simp::Cli::Config::InternalError on empty @key' do
      ci = TestItem.new
      ci.key = ''
      expect{ ci.print_summary }.to raise_error( Simp::Cli::Config::InternalError,
        /@key is empty for TestItem/ )
    end
  end

  describe '#run_command' do
    it 'should reject pipes' do
      command = 'ls /some/missing/path1 | grep path1'
      expect{ @ci.run_command(command) }.to raise_error("Internal error: Invalid pipe '|' in spawn command: <ls /some/missing/path1 | grep path1>")
    end

    it 'returns true when command succeeeds' do
      command = "ls #{__FILE__}"
      expect( @ci.run_command(command)[:status] ).to eq true
      expect( @ci.run_command(command)[:stdout] ).to match "#{__FILE__}"
      expect( @ci.run_command(command)[:stderr] ).to eq ''
    end

    it 'returns false when command fails and ignore_failure is false' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @ci.run_command(command)[:status] ).to eq false
      expect( @ci.run_command(command)[:stdout] ).to eq ''
      expect( @ci.run_command(command)[:stderr] ).to match /ls: cannot access.*\/some\/missing\/path1.*: No such file or directory/
    end

    it 'returns true when command fails and ignore_failure is true' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @ci.run_command(command, true)[:status] ).to eq true
      expect( @ci.run_command(command)[:stdout] ).to eq ''
      expect( @ci.run_command(command)[:stderr] ).to match /ls: cannot access.*\/some\/missing\/path1.*: No such file or directory/
    end
  end

  describe '#execute' do
    it 'should reject pipes' do
      command = 'ls /some/missing/path1 | grep path1'
      expect{ @ci.run_command(command) }.to raise_error("Internal error: Invalid pipe '|' in spawn command: <ls /some/missing/path1 | grep path1>")
    end

    it 'returns true when command succeeeds' do
      command = "ls #{__FILE__}"
      expect( @ci.execute(command) ).to eq true
    end

    it 'returns false when command fails and ignore_failure is false' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @ci.execute(command) ).to eq false
    end

    it 'returns true when command fails and ignore_failure is true' do
      command = 'ls /some/missing/path1 /some/missing/path2'
      expect( @ci.execute(command, true) ).to eq true
    end
  end

  describe '#get_os_value' do
    it 'has nil value when @fact is nil' do
      expect( @ci.get_os_value ).to be_nil
    end

    it 'does not have nil value when @fact is set' do
      ci = TestItem.new
      ci.fact = 'interfaces'
      expect( ci.get_os_value ).to_not be_nil
    end
  end

  describe '#value_required?' do
    context 'when value is not required' do
      [ :none, :global_class].each do |data_type|
        it "returns false for data_type=#{data_type}" do
          ci = TestItem.new
          ci.data_type = data_type
          expect(ci.value_required?).to be false
        end
      end
    end

    context 'when value is required' do
      [ :internal, :cli_params, :global_hiera, :server_hiera].each do |data_type|
        it "returns true for data_type=#{data_type}" do
          ci = TestItem.new
          ci.data_type = data_type
          expect(ci.value_required?).to be true
        end
      end
    end
  end

  describe '#determine_value' do
    context 'when value is not required' do
      it 'does not set value and does not print summary' do
        ci = TestItem.new
        expect(ci).to receive(:value_required?).and_return(false)
        expect(ci).to_not receive(:print_summary)
        ci.determine_value(true, true)
        expect(ci.value).to be_nil
      end
    end

    context 'when skip_query=true and value unset' do
      it 'sets value and prints summary when determine_value_from_default succeeds' do
        ci = TestItem.new
        ci.key = 'test::key'
        ci.skip_query = true
        ci.silent = true
        # next 2 expect() are to ensure determine_value_from_default succeeds
        expect(ci).to receive(:default_value_noninteractive).and_return('valid default')
        expect(ci).to receive(:validate).with('valid default').and_return(true)
        expect(ci).to receive(:print_summary)
        ci.determine_value(true, true) # args don't matter
        expect(ci.value).to eq('valid default')
      end

      it 'fails and does not print summary when determine_value_from_default fails' do
        ci = TestItem.new
        ci.key = 'test::key'
        ci.skip_query = true
        ci.silent = true
        # next 2 expect() are to ensure determine_value_from_default fails
        expect(ci).to receive(:default_value_noninteractive).and_return('invalid default')
        expect(ci).to receive(:validate).with('invalid default').and_return(false)
        expect(ci).to_not receive(:print_summary)
        expect{ ci.determine_value(true, true) }.to raise_error( Simp::Cli::Config::InternalError,
          /Default, noninteractive value for test::key is invalid: 'invalid default'/)
      end
    end

    context 'when skip_query=false and value unset' do
      it 'sets value and prints summary when determine_value_without_override succeeds' do
        ci = TestItem.new
        ci.key = 'test::key'
        ci.silent = true
        # next 2 expect() are to ensure determine_value_without_override succeeds when force_defaults = true
        expect(ci).to receive(:default_value_noninteractive).and_return('valid default')
        expect(ci).to receive(:validate).with('valid default').and_return(true)
        expect(ci).to receive(:print_summary)
        ci.determine_value(false, true) # force_defaults = true
        expect(ci.value).to eq('valid default')
      end

      it 'fails and does not print summary when determine_value_without_override fails' do
        ci = TestItem.new
        ci.key = 'test::key'
        ci.silent = true
        expect{ ci.determine_value(false, false) }.to raise_error( Simp::Cli::Config::ValidationError,
          /FATAL: No answer found for 'test::key'/)
      end
    end

    context 'when skip_query=false and value set' do
      it 'sets value and prints summary when determine_value_with_override succeeds' do
        ci = TestItem.new
        ci.key = 'test::key'
        ci.value = 'valid preset'
        ci.silent = true
        # next expect() is to ensure determine_value_with_override succeeds
        expect(ci).to receive(:validate).with('valid preset').and_return(true)
        expect(ci).to receive(:print_summary)
        ci.determine_value(true, true) # args don't matter
        expect(ci.value).to eq('valid preset')
      end

      it 'fails and does not print summary when determine_value_with_override fails' do
        ci = TestItem.new
        ci.key = 'test::key'
        ci.value = 'invalid preset'
        expect(ci).to receive(:validate).with('invalid preset').and_return(false)
        expect{ ci.determine_value(false, false) }.to raise_error( Simp::Cli::Config::ValidationError,
          /FATAL: 'invalid preset' is not a valid answer for 'test::key'/)
      end
    end
  end

  describe '#determine_value_from_default' do
    it 'sets value and alt_source to :noninteractive when valid default can be determined' do
      ci = TestItem.new
      ci.key = 'test::key'
      expect(ci).to receive(:default_value_noninteractive).and_return('valid default')
      expect(ci).to receive(:validate).with('valid default').and_return(true)
      ci.determine_value_from_default
      expect(ci.value).to eq 'valid default'
      expect(ci.alt_source).to eq :noninteractive
    end

    it 'fails when no valid default can be determined' do
      ci = TestItem.new
      ci.key = 'test::key'
      expect(ci).to receive(:default_value_noninteractive).and_return('invalid default')
      expect(ci).to receive(:validate).with('invalid default').and_return(false)
      expect{ ci.determine_value_from_default }.to raise_error( Simp::Cli::Config::InternalError,
        /Default, noninteractive value for test::key is invalid: 'invalid default'/)
    end
  end

  describe '#determine_value_without_override' do
    context 'when force_defaults=true' do
      it 'sets value to default and sets alt_source to :noninteractive when valid default exists' do
        ci = TestItem.new
        ci.key = 'test::key'
        expect(ci).to receive(:default_value_noninteractive).and_return('valid default')
        expect(ci).to receive(:validate).with('valid default').and_return(true)

        ci.determine_value_without_override(false, true)
        expect(ci.value).to eq 'valid default'
        expect(ci.alt_source).to eq :noninteractive
      end

      it 'calls query and sets alt_source to nil when valid default does not exist and allow_queries=true' do
        ci = TestItem.new
        ci.key = 'test::key'
        expect(ci).to receive(:default_value_noninteractive).and_return(nil)
        expect(ci).to receive(:query)
        ci.determine_value_without_override(true, true)
        expect(ci.alt_source).to be_nil
      end

      it 'fails when valid default does not exist and allow_queries=false' do
        ci = TestItem.new
        ci.key = 'test::key'
        expect(ci).to receive(:default_value_noninteractive).and_return(nil)
        expect{ ci.determine_value_without_override(false, true) }
          .to raise_error( Simp::Cli::Config::ValidationError,
          /FATAL: No valid answer found for 'test::key'/)
      end
    end

    context 'when force_defaults=false' do
      it 'fails when allow_queries=false' do
        ci = TestItem.new
        ci.key = 'test::key'
        expect{ ci.determine_value_without_override(false, false) }
        .to raise_error( Simp::Cli::Config::ValidationError,
          /FATAL: No answer found for 'test::key'/)
      end

      it 'calls query and sets alt_source to nil when  allow_queries=true' do
        ci = TestItem.new
        ci.key = 'test::key'
        expect(ci).to receive(:query)
        ci.determine_value_without_override(true, false)
        expect(ci.alt_source).to be_nil
      end
    end
  end

  describe '#determine_value_with_override' do
    context 'valid preset value' do
      it 'keeps preset value and sets alt_source to :answered' do
        ci = TestItem.new
        ci.key = 'test::key'
        ci.value = 'valid preset'
        expect(ci).to receive(:validate).with('valid preset').and_return(true)

        ci.determine_value_with_override(false, false) # args do not matter
        expect(ci.value).to eq 'valid preset'
        expect(ci.alt_source).to eq :answered
      end
    end

    context 'invalid preset value' do
      it 'fails if allow_queries and force_defaults are both false' do
        ci = TestItem.new
        ci.key = 'test::key'
        ci.value = 'invalid preset'
        expect(ci).to receive(:validate).with('invalid preset').and_return(false)
        expect{ ci.determine_value_with_override(false, false) }
          .to raise_error( Simp::Cli::Config::ValidationError,
          /FATAL: 'invalid preset' is not a valid answer for 'test::key'/)
      end

      it 'calls determine_value_without_override when allow_queries + force_defaults are not both false' do
        ci = TestItem.new
        ci.key = 'test::key'
        ci.value = 'invalid preset'
        expect(ci).to receive(:validate).with('invalid preset').and_return(false)
        expect(ci).to receive(:determine_value_without_override).with(true,true)
        ci.determine_value_with_override(true, true)
      end


      it 'does not hide validation error of a silent autogenerated Item' do
        ci = TestItem.new
        ci.key = 'test::key'
        ci.value = 'invalid preset'
        ci.silent = true
        ci.skip_query = true
        expect(ci).to receive(:validate).with('invalid preset').and_return(false).twice
        expect(ci).to receive(:determine_value_without_override).with(true,true)

        ci.determine_value_with_override(true, true)
        expect(ci.silent).to be false
        expect(ci.skip_query).to be false
      end
    end
  end
end
