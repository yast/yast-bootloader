# encoding: utf-8

# File:
#      bootloader/routines/bootloader_preupdate.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Client for handling pre-update bootloader configuration
#
# Authors:
#      Jozef Uhliarik <juhliarik@suse.cz>
#
#
module Yast
  class BootloaderPreupdateClient < Client
    def main

      textdomain "bootloader"


      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Installation"
      Yast.import "GetInstArgs"
      Yast.import "Mode"
      Yast.import "Arch"
      Yast.import "BootGRUB"
      Yast.import "StorageUpdate"

      Builtins.y2milestone("starting bootloader_preupdate")


      if GetInstArgs.going_back # going backwards?
        return :auto # don't execute this once more
      end

      if Mode.update && (Arch.x86_64 || Arch.i386)
        # save some sysconfig variables
        # register new agent pointing into the mounted filesystem
        @sys_agent = path(".target.sysconfig.bootloader")

        @target_sysconfig_path = Ops.add(
          Installation.destdir,
          "/etc/sysconfig/bootloader"
        )
        SCR.RegisterAgent(
          path(".target.sysconfig.bootloader"),
          term(:ag_ini, term(:SysConfigFile, @target_sysconfig_path))
        )

        @bl = Convert.to_string(
          SCR.Read(Builtins.add(@sys_agent, path(".LOADER_TYPE")))
        )

        @ret = nil
        if @bl == "grub"
          Builtins.y2milestone("updating device map...")
          if preUpdateDeviceMap
            Builtins.y2milestone("Update device map is done successful")
            BootGRUB.update_device_map_done = true
          else
            Builtins.y2error("Update device map failed")
            BootGRUB.update_device_map_done = false
          end

          Builtins.y2milestone("Calling storage update")
          StorageUpdate.Update(
            Installation.installedVersion,
            Installation.updateVersion
          )
        end

        return :back if @ret == :back

        return :next if @ret == :next
      end

      Builtins.y2milestone("finish bootloader_preupdate")

      :auto
    end

    def preUpdateDeviceMap
      ret = false
      device_map = Convert.to_string(
        WFM.Read(
          path(".local.string"),
          Ops.add(Installation.destdir, "/boot/grub/device.map")
        )
      )
      if device_map == nil
        Builtins.y2error("Reading device map failed.")
        return false
      end
      Builtins.y2milestone("Device map: %1", device_map)

      BootCommon.InitializeLibrary(true, "grub")
      BootCommon.setLoaderType("grub")
      new_files = {}
      Ops.set(new_files, "/boot/grub/device.map", device_map)
      ret = BootCommon.SetFilesContents(new_files)
      if !ret
        Builtins.y2error("SetFilesContents failed.")
        return false
      end
      BootStorage.device_mapping = BootCommon.GetDeviceMap

      if BootStorage.device_mapping == nil ||
          Builtins.size(BootStorage.device_mapping) == 0
        Builtins.y2error("Parsing device map failed or it is empty.")
        return false
      end
      BootCommon.UpdateDeviceMap

      ret = BootCommon.SetDeviceMap(BootStorage.device_mapping)
      if !ret
        Builtins.y2error("Set device map failed.")
        return false
      end

      new_files = BootCommon.GetFilesContents
      Builtins.y2milestone("new content file: %1", new_files)

      content_dev_map = Ops.get(new_files, "/boot/grub/device.map")

      if content_dev_map != nil && content_dev_map != ""
        Builtins.y2milestone("writing device map: %1", content_dev_map)
        WFM.Write(
          path(".local.string"),
          Ops.add(Installation.destdir, "/boot/grub/device.map"),
          content_dev_map
        )
      end

      ret
    end
  end
end

Yast::BootloaderPreupdateClient.new.main
