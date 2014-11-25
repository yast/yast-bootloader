require "yast"

# class is responsible for detection, encryption and writing of grub2 password protection
class GRUB2Pwd
  YAST_BASH_PATH = Yast::Path.new(".target.bash_output")
  PWD_ENCRYPTION_FILE = "/etc/grub.d/42_password"

  def used?
    Yast.import "FileUtils"

    Yast::FileUtils.Exists PWD_ENCRYPTION_FILE
  end

  def enable(password)
    enc_passwd = encrypt(password)

    file_content = "#! /bin/sh\n" +
      "exec tail -n +3 $0\n" +
      "# File created by YaST and next password change in YaST will overwrite it\n" +
      "set superusers=\"root\"\n" +
      "password_pbkdf2 root #{enc_passwd}\n" +
      "export superusers"

    Yast::SCR.Write(
      Yast::Path.new(".target.string"),
      [PWD_ENCRYPTION_FILE, 0700],
      file_content
    )
  end

  def disable
    return unless used?

    Yast::SCR.Execute(YAST_BASH_PATH, "rm '#{PWD_ENCRYPTION_FILE}'")
  end

private

  def encrypt(password)
    Yast.import "String"

    quoted_password = Yast::String.Quote(password)
    result = Yast::WFM.Execute(YAST_BASH_PATH,
      "echo '#{quoted_password}\n#{quoted_password}\n' | LANG=C grub2-mkpasswd-pbkdf2"
    )

    if result["exit"] != 0
      raise "Failed to create encrypted password for grub2. Command output: #{result["stderr"]}"
    end

    pwd_line = result["stdout"].split("\n").grep(/password is/).first
    if !pwd_line
      raise "INTERNAL ERROR: output do not contain encrypted password. Output: #{result["stdout"]}"
    end

    ret = pwd_line[/^.*password is\s*(\S+)/,1]
    if !ret
      raise "INTERNAL ERROR: output do not contain encrypted password. Output: #{result["stdout"]}"
    end

    return ret
  end
end
