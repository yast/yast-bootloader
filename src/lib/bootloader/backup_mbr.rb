require "yast"

Yast.import "BootCommon"

module Bootloader
  class BackupMBR
    class << self
      include Yast::Logger
      BASH_PATH = Yast::Path.new(".target.bash")
      BASH_OUTPUT_PATH = Yast::Path.new(".target.bash_output")
      # Creates backup of MBR or PBR of given device.
      # Backup is stored in /var/lib/YaST2/backup_boot_sectors, in logs
      # directory and if it is MBR of primary disk, then also in /boot/backup_mbr
      def backup_device(device)
        device_file = Yast::Builtins.mergestring(Yast::Builtins.splitstring(device, "/"), "_")
        device_file_path = Yast::Ops.add(
          "/var/lib/YaST2/backup_boot_sectors/",
          device_file
        )
        device_file_path_to_logs = Yast::Ops.add("/var/log/YaST2/", device_file)
        Yast::SCR.Execute(
          BASH_PATH,
          "test -d /var/lib/YaST2/backup_boot_sectors || mkdir /var/lib/YaST2/backup_boot_sectors"
        )
        if Yast::Ops.greater_than(Yast::SCR.Read(Yast::Path.new(".target.size"), device_file_path), 0)
          contents = Yast::Convert.convert(
            Yast::SCR.Read(Yast::Path.new(".target.dir"), "/var/lib/YaST2/backup_boot_sectors"),
            :from => "any",
            :to   => "list <string>"
          )
          contents = Yast::Builtins.filter(contents) do |c|
            Yast::Builtins.regexpmatch(
              c,
              Yast::Builtins.sformat("%1-.*-.*-.*-.*-.*-.*", device_file)
            )
          end
          contents = Yast::Builtins.sort(contents)
          index = 0
          siz = Yast::Builtins.size(contents)
          while Yast::Ops.less_than(Yast::Ops.add(index, 10), siz)
            Yast::SCR.Execute(
              Yast::Path.new(".target.remove"),
              Yast::Builtins.sformat(
                "/var/lib/YaST2/backup_boot_sectors/%1",
                Yast::Ops.get(contents, index, "")
              )
            )
            index = Yast::Ops.add(index, 1)
          end
          change_date = grub_getFileChangeDate(device_file_path)
          Yast::SCR.Execute(
            BASH_PATH,
            Yast::Builtins.sformat("/bin/mv %1 %1-%2", device_file_path, change_date)
          )
        end
        Yast::SCR.Execute(
          BASH_PATH,
          Yast::Builtins.sformat(
            "/bin/dd if=%1 of=%2 bs=512 count=1 2>&1",
            device,
            device_file_path
          )
        )
        # save MBR to yast2 log directory
        Yast::SCR.Execute(
          BASH_PATH,
          Yast::Builtins.sformat(
            "/bin/dd if=%1 of=%2 bs=512 count=1 2>&1",
            device,
            device_file_path_to_logs
          )
        )
        if device == Yast::BootCommon.mbrDisk
          Yast::SCR.Execute(
            BASH_PATH,
            Yast::Builtins.sformat(
              "/bin/dd if=%1 of=%2 bs=512 count=1 2>&1",
              device,
              "/boot/backup_mbr"
            )
          )

          # save thinkpad MBR
          if Yast::BootCommon.ThinkPadMBR(device)
            device_file_path_thinkpad = Yast::Ops.add(device_file_path, "thinkpadMBR")
            log.info("Backup thinkpad MBR")
            Yast::SCR.Execute(
              BASH_PATH,
              Yast::Builtins.sformat(
                "cp %1 %2 2>&1",
                device_file_path,
                device_file_path_thinkpad
              )
            )
          end
        end
      end

    private
      # Get last change time of file
      # @param [String] filename string name of file
      # @return [String] last change date as YYYY-MM-DD-HH-MM-SS
      def grub_getFileChangeDate(filename)
        stat = Yast::SCR.Read(Yast::Path.new(".target.stat"), filename)
        ctime = stat["ctime"] or raise "Cannot get modification time of file #{filename}"
        time = DateTime.strptime(ctime.to_s, "%s")

        time.strftime("%Y-%m-%d-%H-%M-%S")
      end
    end
  end
end
