require "yast"

class GRUB2Pwd
  YAST_BASH_PATH = Yast::Path.new(".target.bash_output")
  PWD_ENCRYPTION_FILE = "/etc/grub.d/42_password"

  def used?
    Yast.import "FileUtils"

    Yast::FileUtils.Exists PWD_ENCRYPTION_FILE
  end

  def enable(password)
    enc_passwd = encrypt(password)

    file_content = "/bin/sh\n" +
      "exec tail -n +3 $0\n" +
      "# File created by YaST and next password change in YaST will overwrite it\n" +
      "set superusers=\"root\"\n" +
      "password_pbkdf2 root #{enc_passwd}\n" +
      "export superusers"

    Yast::SCR.Write(Yast::Path.new(".target.string"), file_content)
  end

  def disable
    return unless used?

    Yast::SCR.Execute(YAST_BASH_PATH, "rm '#{PWD_ENCRYPTION_FILE}'")
  end

private

  def encrypt(password)
    result = Yast::SCR.Execute(YAST_BASH_PATH,
      "echo -e \"#{password}\\n#{password}\" | grub2-mkpasswd-pbkdf"
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
