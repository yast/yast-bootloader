require "yast"

Yast.import "BootCommon"

module Bootloader
  class BackupMBR
    class << self
      include Yast::Logger
      BASH_PATH = Yast::Path.new(".target.bash")
      BASH_OUTPUT_PATH = Yast::Path.new(".target.bash_output")
      MAIN_BACKUP_DIR = "/var/lib/YaST2/backup_boot_sectors/"
      KEPT_BACKUPS = 10
      # Creates backup of MBR or PBR of given device.
      # Backup is stored in /var/lib/YaST2/backup_boot_sectors, in logs
      # directory and if it is MBR of primary disk, then also in /boot/backup_mbr
      def backup_device(device)
        device_file = device.tr("/", "_")
        device_file_path = MAIN_BACKUP_DIR + device_file
        device_file_path_to_logs = "/var/log/YaST2/" + device_file
        Yast::SCR.Execute(BASH_PATH, "mkdir -p #{MAIN_BACKUP_DIR}")

        # check if file exists
        if Yast::SCR.Read(Yast::Path.new(".target.size"), device_file_path) > 0
          cleanup_backups(device_file)
          change_date = formated_file_ctime(device_file_path)
          Yast::SCR.Execute(
            BASH_PATH,
            Yast::Builtins.sformat("/bin/mv %1 %1-%2", device_file_path, change_date)
          )
        end
        copy_br(device, device_file_path)
        # save MBR to yast2 log directory
        copy_br(device, device_file_path_to_logs)

        if device == Yast::BootCommon.mbrDisk
          copy_br(device, "/boot/backup_mbr")

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
      def formated_file_ctime(filename)
        stat = Yast::SCR.Read(Yast::Path.new(".target.stat"), filename)
        ctime = stat["ctime"] or raise "Cannot get modification time of file #{filename}"
        time = DateTime.strptime(ctime.to_s, "%s")

        time.strftime("%Y-%m-%d-%H-%M-%S")
      end

      def copy_br(device, target_path)
        Yast::SCR.Execute(
          BASH_PATH,
          "/bin/dd if=#{device} of=#{target_path} bs=512 count=1 2>&1"
        )
      end

      def cleanup_backups(device_file)
        files = Yast::SCR.Read(Yast::Path.new(".target.dir"), MAIN_BACKUP_DIR)
        # clean only backups for this device
        files.select! do |c|
          c =~ /#{Regexp.escape(device_file)}-\d{4}(?:-\d{2}){5}/
        end
        # and sort so we can benefit from its ascending order
        files.sort!
        files.drop(KEPT_BACKUPS).each do |file_name|
          Yast::SCR.Execute(
            Yast::Path.new(".target.remove"),
            MAIN_BACKUP_DIR + file_name
          )
        end
      end
    end
  end
end
