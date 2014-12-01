# encoding: utf-8

# File:
#  bootloader_finish.ycp
#
# Module:
#  Step of base installation finish
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#  Olaf Dabrunz <od@suse.de>
#
# $Id$
#
require "bootloader/kexec"

module Yast
  class BootloaderFinishClient < Client
    def main
      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "Bootloader"
      Yast.import "Installation"
      Yast.import "Linuxrc"
      Yast.import "Misc"
      Yast.import "Mode"
      Yast.import "BootCommon"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("starting bootloader_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 3,
          # progress step title
          "title" => _(
            "Saving bootloader configuration..."
          ),
          "when"  => [:installation, :live_installation, :update, :autoinst]
        }
      elsif @func == "Write"
        # provide the /dev content from the inst-sys also inside the chroot of just the upgraded system
        # umount of this bind mount will happen in umount_finish
        if Mode.update
          @cmd = Ops.add(
            Ops.add("targetdir=", Installation.destdir),
            "\n" \
              "if test ${targetdir} = / ; then echo targetdir is / ; exit 1 ; fi\n" \
              "grep -E \"^[^ ]+ ${targetdir}/dev \" < /proc/mounts\n" \
              "if test $? = 0\n" \
              "then\n" \
              "\techo targetdir ${targetdir} already mounted.\n" \
              "\texit 1\n" \
              "else\n" \
              "\tmkdir -vp ${targetdir}/dev\n" \
              "\tcp --preserve=all --recursive --remove-destination /lib/udev/devices/* ${targetdir}/dev\n" \
              "\tmount -v --bind /dev ${targetdir}/dev\n" \
              "fi\n"
          )
          Builtins.y2milestone("mount --bind cmd: %1", @cmd)
          @out = Convert.to_map(WFM.Execute(path(".local.bash_output"), @cmd))
          if Ops.get_integer(@out, "exit", 0) != 0
            Builtins.y2error("unable to bind mount /dev in chroot")
          end
          Builtins.y2milestone("mount --bind /dev /mnt/dev output: %1", @out)
        end
        # --------------------------------------------------------------
        # message after first round of packet installation
        # now the installed system is run and more packages installed
        # just warn the user that the screen is going back to text mode
        # and yast2 will come up again.
        # dont mention this "going back to text mode" here, maybe this
        # wont be necessary in the final version

        # we should tell the user to remove the cd on an SMP or Laptop system
        # where we do a hard reboot. However, the cdrom is still mounted here
        # and cant be removed.

        @finish_ret = nil
        if Arch.s390
          @reipl_client = "reipl_bootloader_finish"

          # Calling a special reIPL client
          # it returns a result map (keys: (boolean) different, (string) ipl_msg)

          if WFM.ClientExists(@reipl_client)
            @finish_ret = Convert.to_map(WFM.call(@reipl_client))
            Builtins.y2milestone(
              "result of reipl_bootloader_finish [%1, %2]",
              Ops.get_boolean(@finish_ret, "different", true),
              Ops.get_string(@finish_ret, "ipl_msg", "N/A2")
            )
            Builtins.y2milestone(
              "finish_ret[\"different\"]:true == true : %1",
              Ops.get_boolean(@finish_ret, "different", true) == true
            )
            if Ops.get_boolean(@finish_ret, "different", false) == true
              Builtins.y2milestone("finish_ret[\"different\"] is true")
            else
              Builtins.y2milestone(
                "finish_ret[\"different\"] is not true (either undefined or false)"
              )
            end
          else
            Builtins.y2error("No such client: %1", @reipl_client)
          end
        end

        if Arch.s390 && Ops.get_boolean(@finish_ret, "different", true) == true
          # reIPL message
          @ipl_msg = ""
          @ipl_msg = Ops.get_string(@finish_ret, "ipl_msg", "")

          # TRANSLATORS: reboot message
          # %1 is replaced with additional message from reIPL
          Misc.boot_msg = Builtins.sformat(
            _(
              "\n" \
                "Your system will now shut down.%1\n" \
                "For details, read the related chapter \n" \
                "in the documentation. \n"
            ),
            @ipl_msg
          )
        else
          # Final message after all packages from CD1 are installed
          # and we're ready to start (boot into) the installed system
          # Message that will be displayed along with information
          # how the boot loader was installed
          Misc.boot_msg = _("The system will reboot now...")
        end

        #--------------------------------------------------------------
        # Install bootloader (always, see #23018)
        # should also set Misc::boot_msg appropriate

        # In Mode::update(), the configuration is not yet read (for some
        # unresearched reason). Therefore, for Mode::update(), there is another
        # call of ResolveSymlinksInSections() after a Read() in
        # Bootloader::ReadOrProposeIfNeeded() (which is called the first time
        # Write() is reached from the call-chain that starts below:
        # Bootloader::Update() -> Write()).

        @retcode = false

        if !Mode.update
          @retcode = Bootloader.WriteInstallation
        else
          @retcode = Bootloader.Update

          # workaround for packages that forgot to update initrd(bnc#889616)
          # do not use Initrd module as it can also change configuration, which we do not want
          res = SCR.Execute(path(".target.bash_output"), "/sbin/mkinitrd")
          Builtins.y2milestone("Regerate initrd with result #{res}")
        end

        # FIXME: workaround grub2 need manual rerun of branding due to overwrite by
        # pbl. see bnc#879686 and bnc#901003
        if Bootloader.getLoaderType =~ /grub2/
          prefix = Installation.destdir
          branding_activator = Dir["#{prefix}/usr/share/grub2/themes/*/activate-theme"].first
          if branding_activator
            branding_activator = branding_activator[prefix.size..-1]
            res = SCR.Execute(path(".target.bash_output"), branding_activator)
            Builtins.y2milestone("Reactivate branding with #{branding_activator} and result #{res}")
            res = SCR.Execute(path(".target.bash_output"), "/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg")
            Builtins.y2milestone("Regenerating config for branding with result #{res}")
          end
        end

        if @retcode
          # re-read external changes, then boot through to second stage of
          # installation or update
          Bootloader.Read
          # fate #303395: Use kexec to avoid booting between first and second stage
          # copy vmlinuz, initrd and flush kernel option into /var/lib/YaST2
          retcode = false
          if Linuxrc.InstallInf("kexec_reboot") == "1"
            kexec = ::Bootloader::Kexec.new
            retcode = kexec.prepare_environment
          else
            Builtins.y2milestone("Installation started with kexec_reboot set 0")
          end

          # (bnc #381192) don't use it if kexec is used
          # update calling onetime boot bnc #339024
          if !retcode
            @ret = Bootloader.FlagOnetimeBoot(Bootloader.getDefaultSection)
          end
        else
          return @retcode
        end
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("bootloader_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::BootloaderFinishClient.new.main
