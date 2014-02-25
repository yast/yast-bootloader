#! /usr/bin/env rspec

require_relative "./test_helper"

require "bootloader/grub2pwd"

describe GRUB2Pwd do
  subject { GRUB2Pwd.new }

  def mock_file_presence(exists)
    Yast.import "FileUtils"
    expect(Yast::FileUtils).to receive(:Exists).with("/etc/grub.d/42_password").
      and_return(exists)
  end

  describe "#used?" do
    it "return true if exists file #{GRUB2Pwd::PWD_ENCRYPTION_FILE}" do
      mock_file_presence(true)
      expect(subject.used?).to be_true
    end
  end

  describe "#disable" do
    it "removes file #{GRUB2Pwd::PWD_ENCRYPTION_FILE} when exists" do
      mock_file_presence(true)

      expect(Yast::SCR).to receive(:Execute).with(kind_of(Yast::Path),"rm '#{GRUB2Pwd::PWD_ENCRYPTION_FILE}'")

      subject.disable
    end

    it "do nothing if file #{GRUB2Pwd::PWD_ENCRYPTION_FILE} does not exist" do
      mock_file_presence(false)

      expect(Yast::SCR).to receive(:Execute).never

      subject.disable
    end
  end

  describe "#enabled" do
    it "write encrypted password to #{GRUB2Pwd::PWD_ENCRYPTION_FILE}" do
      passwd = "grub.pbkdf2.sha512.10000.774E325959D6D7BCFB7384A0245674D83D0D540A89C02FEA81E35489F8DE7ADFD93988190AD9857A0FFF363825DDF97C8F4E658D8CC49FC4A22C053B08AB3EFE.6FB19FF26FD03D85C40A33D8BA7C04E72EDE3DD5D7080C177553A4FED370F71C579AF0B15B3B93ECECEA355469A4B6D0560BFB53ED35DDA0B80F5363BFBD54E4"
      success_stdout = <<EOF
      Enter password: 

      Reenter password: 
      PBKDF2 hash of your password is #{passwd}
EOF

      expect(Yast::SCR).to receive(:Execute).
        with(kind_of(Yast::Path),/grub2-mkpasswd/).
        and_return(
          "exit"   => 0,
          "stderr" => "",
          "stdout" => success_stdout
        )
      expect(Yast::SCR).to receive(:Write).with(kind_of(Yast::Path),/#{passwd}/)

      subject.enable("really strong password")
    end

    it "raise exception if grub2-mkpasswd-pbkdf failed" do
      expect(Yast::SCR).to receive(:Execute).
        with(kind_of(Yast::Path),/grub2-mkpasswd/).
        and_return(
          "exit"   => 1,
          "stderr" => "bad error",
          "stdout" => ""
        )
      expect(Yast::SCR).to receive(:Write).never

      expect{subject.enable("really strong password")}.to raise_error(RuntimeError, /bad error/)
    end

    it "raise exception if grub2-mkpasswd-pbkdf do not provide password" do
      expect(Yast::SCR).to receive(:Execute).
        with(kind_of(Yast::Path),/grub2-mkpasswd/).
        and_return(
          "exit"   => 0,
          "stderr" => "",
          "stdout" => "bad output"
        )
      expect(Yast::SCR).to receive(:Write).never

      expect{subject.enable("really strong password")}.to raise_error(RuntimeError, /bad output/)
    end


    it "raise exception if grub2-mkpasswd-pbkdf create password line but without password" do
      expect(Yast::SCR).to receive(:Execute).
        with(kind_of(Yast::Path),/grub2-mkpasswd/).
        and_return(
          "exit"   => 0,
          "stderr" => "",
          "stdout" => "password is"
        )
      expect(Yast::SCR).to receive(:Write).never

      expect{subject.enable("really strong password")}.to raise_error(RuntimeError, /password is/)
    end
  end
end
