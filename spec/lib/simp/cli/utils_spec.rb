require 'simp/cli/utils'
require 'rspec/its'
require 'spec_helper'
require 'tmpdir'

describe Simp::Cli::Utils do

  describe '.show_wait_spinner' do
    it 'should return result of block' do
      result = Simp::Cli::Utils.show_wait_spinner {
        sleep 1
        'block result'
      }
      expect( result ).to eq('block result')
    end

    it 'should kill spinning thread when block raises' do
      base_num_threads = Thread.list.select {|thread| thread.status == "run"}.count
      error = nil
      begin
        Simp::Cli::Utils.show_wait_spinner {
          sleep 1
          raise 'something bad happened in block'
        }
      rescue RuntimeError => e
        error = e.message
      end

      expect( error ).to eq('something bad happened in block')

      # This **ASSUMES** we don't have parallel tests enabled...
      current_num_threads = Thread.list.select {|thread| thread.status == "run"}.count
      expect( current_num_threads ).to eq(base_num_threads)
    end
  end

  describe '.validate_password' do
    it 'validates good passwords' do
      expect{ Simp::Cli::Utils.validate_password 'A=V3ry=Go0d=P@ssw0r!' }
        .to_not raise_error
    end

    it 'raises an PasswordError on short passwords' do
      expect{ Simp::Cli::Utils.validate_password 'a@1X' }.to raise_error( Simp::Cli::PasswordError )
    end

    it 'raises an PasswordError on simple passwords' do
      expect{ Simp::Cli::Utils.validate_password 'aaaaaaaaaaaaaaa' }.to raise_error( Simp::Cli::PasswordError )
    end
  end

  describe '.validate_password_with_cracklib' do
    it 'validates good passwords' do
      expect{ Simp::Cli::Utils.validate_password 'A=V3ry=Go0d=P@ssw0r!' }
        .to_not raise_error
    end

    it 'raises an PasswordError on short passwords' do
      expect{ Simp::Cli::Utils.validate_password 'a@1X' }.to raise_error( Simp::Cli::PasswordError )
    end

    it 'raises an PasswordError on simple passwords' do
      expect{ Simp::Cli::Utils.validate_password '012345678901234' }.to raise_error( Simp::Cli::PasswordError )
    end
  end

  describe '.generate_password' do
    let(:default_chars) do
      (("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a).map do|x|
          x = Regexp.escape(x)
      end
    end

    let(:safe_special_chars) do
      ['@','%','-','_','+','=','~'].map do |x|
        x = Regexp.escape(x)
      end
    end

    let(:unsafe_special_chars) do
      (((' '..'/').to_a + ('['..'`').to_a + ('{'..'~').to_a)).map do |x|
        x = Regexp.escape(x)
      end - safe_special_chars
    end

    context 'with defaults' do
      it 'should return a password of the default length' do
        expect( Simp::Cli::Utils.generate_password.size ).to \
          eq Simp::Cli::Utils::DEFAULT_PASSWORD_LENGTH
      end

      it 'should return a password with default and safe special characters' do
        result = Simp::Cli::Utils.generate_password
        expect(result).to match(/(#{default_chars.join('|')})/)
        expect(result).to match(/(#{(safe_special_chars).join('|')})/)
        expect(result).not_to match(/(#{(unsafe_special_chars).join('|')})/)
      end

      it 'should return a password that does not start/end with a special char' do
        expect( Simp::Cli::Utils.generate_password ).to_not match /^[@%\-_+=~]|[@%\-_+=~]$/
      end
    end

    context 'with custom settings that validate' do
      it 'should return a password of the specified length' do
        expect( Simp::Cli::Utils.generate_password( 73 ).size ).to eq 73
      end

      it 'should return a password that contains all special characters ' +
         'if complexity is 2' do

        result = Simp::Cli::Utils.generate_password(32, 2)
        expect(result.length).to eql(32)
        expect(result).to match(/(#{default_chars.join('|')})/)
        expect(result).to match(/(#{(unsafe_special_chars).join('|')})/)
      end
    end

    # these cases require validation to be turned off
    context 'with custom settings that do not validate' do
      it 'should return a password that contains no special chars ' +
         'if complexity is 0' do

        result = Simp::Cli::Utils.generate_password(32, 0, false, 10, false)
        expect(result).to match(/(#{default_chars.join('|')})/)
        expect(result).not_to match(/(#{(safe_special_chars).join('|')})/)
        expect(result).not_to match(/(#{(unsafe_special_chars).join('|')})/)
      end

      it 'should return a password that only contains "safe" special chars ' +
         'if complexity is 1 and complex_only is true' do

        result = Simp::Cli::Utils.generate_password(32, 1, true, 10, false)
        expect(result.length).to eql(32)
        expect(result).not_to match(/(#{default_chars.join('|')})/)
        expect(result).to match(/(#{(safe_special_chars).join('|')})/)
        expect(result).not_to match(/(#{(unsafe_special_chars).join('|')})/)
      end

      it 'should return a password that only contains all special chars ' +
         'if complexity is 2 and complex_only is true' do

        result = Simp::Cli::Utils.generate_password(32, 2, true, 10, false)
        expect(result.length).to eql(32)
        expect(result).to_not match(/(#{default_chars.join('|')})/)
        expect(result).to match(/(#{(unsafe_special_chars).join('|')})/)
      end
    end

    context 'errors' do
      it 'fails when password generation times out' do
        allow(Timeout).to receive(:timeout).with(20).and_raise(
          Timeout::Error, 'Timeout')

        expect{ Simp::Cli::Utils.generate_password(8, 2, true, 20, true) }
          .to raise_error(Simp::Cli::PasswordError,
          'Failed to generate password in allotted time')
      end
    end
  end

  describe '.yes_or_no' do
    before :each do
      @input = StringIO.new
      @output = StringIO.new
      @prev_terminal = $terminal
      $terminal = HighLine.new(@input, @output)
    end

    after :each do
      @input.close
      @output.close
      $terminal = @prev_terminal
    end

    it "when default_yes=true, prompts, accepts default of 'yes' and " +
       'returns true' do

      @input << "\n"
      @input.rewind

      expect( Simp::Cli::Utils.yes_or_no('Remove backups', true) )
        .to eq true

      expect( @output.string.uncolor ).to eq '> Remove backups: |yes| '
    end

    it "when default_yes=false, prompts, accepts default of 'no' and " +
       'returns false' do

      @input << "\n"
      @input.rewind
      expect( Simp::Cli::Utils.yes_or_no('Remove backups', false) )
        .to eq false

      expect( @output.string.uncolor ).to eq '> Remove backups: |no| '
    end

    ['yes', 'YES', 'y', 'Y'].each do |response|
      it "accepts '#{response}' and returns true" do
        @input << "#{response}\n"
        @input.rewind
        expect( Simp::Cli::Utils.yes_or_no('Remove backups', false) )
          .to eq true
      end
    end

    ['no', 'NO', 'n', 'N'].each do |response|
      it "accepts '#{response}' and returns false" do
        @input << "#{response}\n"
        @input.rewind
        expect( Simp::Cli::Utils.yes_or_no('Remove backups', false) )
          .to eq false
      end
    end

    it 're-prompts user when user does not enter a string that begins ' +
       'with Y, y, N, or n' do

      @input << "oops\n"
      @input << "I\n"
      @input << "can't\n"
      @input << "type!\n"
      @input << "yes\n"
      @input.rewind
      expect( Simp::Cli::Utils.yes_or_no('Remove backups', false) )
        .to eq true
    end
  end

end
