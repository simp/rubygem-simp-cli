require 'simp/cli/passgen/utils'
require 'spec_helper'
require 'test_utils/mock_logger'

describe Simp::Cli::Passgen::Utils do
  describe '.get_password' do
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

    let(:password1) { 'A=V3ry=Go0d=P@ssw0r!' }

    it 'accepts a valid password when entered twice' do
      @input << "#{password1}\n"
      @input << "#{password1}\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.get_password ).to eq password1

      expected = <<~EOM
        > Enter password: ********************
        > Confirm password: ********************
      EOM
      expect(@output.string.uncolor).to eq expected
    end

    it 're-prompts when the entered password fails system validation' do
      @input << "short\n"
      @input << "#{password1}\n"
      @input << "#{password1}\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.get_password ).to eq password1

      expected = <<~EOM
        > Enter password: *****
        > Enter password: ********************
        > Confirm password: ********************
      EOM
      expect(@output.string.uncolor).to eq expected
    end

    it 'starts over when the confirm password does not match entered password' do
      @input << "#{password1}\n"
      @input << "bad confirm\n"
      @input << "#{password1}\n"
      @input << "#{password1}\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.get_password ).to eq password1

      expected = <<~EOM
        > Enter password: ********************
        > Confirm password: ***********
        > Enter password: ********************
        > Confirm password: ********************
      EOM
      expect(@output.string.uncolor).to eq expected
    end

    it 'fails after 5 failed start-over attempts' do
      @input << "#{password1}\n"
      @input << "bad confirm 1\n"
      @input << "#{password1}\n"
      @input << "bad confirm 2\n"
      @input << "#{password1}\n"
      @input << "bad confirm 3\n"
      @input << "#{password1}\n"
      @input << "bad confirm 4\n"
      @input << "#{password1}\n"
      @input << "bad confirm 5\n"
      @input.rewind
      expect{ Simp::Cli::Passgen::Utils.get_password }
        .to raise_error(Simp::Cli::ProcessingError)
    end

    it 'accepts an simple password when system validation disabled' do
      simple_password = 'password'
      @input << "#{simple_password}\n"
      @input << "#{simple_password}\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.get_password(5, false) )
        .to eq simple_password
    end

    it 'rejects a short password when system validation disabled' do
      short_password = '12345678'
      ok_password = '123456789'
      @input << "#{short_password}\n"
      @input << "#{short_password}\n"
      @input << "#{ok_password}\n"
      @input << "#{ok_password}\n"
      @input.rewind
      expect( Simp::Cli::Passgen::Utils.get_password(5, false, 9) )
        .to eq ok_password
   end
  end

  describe '.validate_password_length' do
    it 'returns true when password has valid length' do
      expect( Simp::Cli::Passgen::Utils.validate_password_length('1234', 4) )
        .to be true
    end

    it 'returns false when password has invalid length' do
      expect( Simp::Cli::Passgen::Utils.validate_password_length('1234', 5) )
        .to be false
    end
  end
end
