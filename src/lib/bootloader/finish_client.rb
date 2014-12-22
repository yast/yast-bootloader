require "bootloader/kexec"
require "installation/finish_client"

module Bootloader
  # Finish client for bootloader configuration
  class FinishClient < ::Installation::FinishClient
    include Yast::I18n

    BASH_PATH = Yast::Path.new(".target.bash_output")

    def initialize
      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "Bootloader"
      Yast.import "Installation"
      Yast.import "Linuxrc"
      Yast.import "Misc"
      Yast.import "Mode"
      Yast.import "BootCommon"
    end

    def steps
      3
    end

    def title
      _("Saving bootloader configuration...")
    end

    def modes
      [:installation, :live_installation, :update, :autoinst]
    end

    def write
      # provide the /dev content from the inst-sys also inside the chroot of just the upgraded system
      # umount of this bind mount will happen in umount_finish
      update_mount

      # message after first round of packet installation
      # now the installed system is run and more packages installed
      # just warn the user that the screen is going back to text mode
      # and yast2 will come up again.
      set_boot_msg

      retcode = false

      if !Yast::Mode.update
        retcode = Yast::Bootloader.WriteInstallation
      else
        retcode = Yast::Bootloader.Update

        # workaround for packages that forgot to update initrd(bnc#889616)
        # do not use Initrd module as it can also change configuration, which we do not want
        res = Yast::SCR.Execute(BASH_PATH, "/sbin/mkinitrd")
        log.info "Regerate initrd with result #{res}"
      end

      # FIXME: workaround grub2 need manual rerun of branding due to overwrite by
      # pbl. see bnc#879686 and bnc#901003
      if Yast::Bootloader.getLoaderType =~ /grub2/
        prefix = Yast::Installation.destdir
        branding_activator = Dir["#{prefix}/usr/share/grub2/themes/*/activate-theme"].first
        if branding_activator
          branding_activator = branding_activator[prefix.size..-1]
          res = Yast::SCR.Execute(BASH_PATH, branding_activator)
          log.info "Reactivate branding with #{branding_activator} and result #{res}"
          res = Yast::SCR.Execute(BASH_PATH, "/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg")
          log.info "Regenerating config for branding with result #{res}"
        end
      end

      if retcode
        # re-read external changes, then boot through to second stage of
        # installation or update
        Yast::Bootloader.Read
        # fate #303395: Use kexec to avoid booting between first and second stage
        # copy vmlinuz, initrd and flush kernel option into /var/lib/YaST2
        ret = false
        if Yast::Linuxrc.InstallInf("kexec_reboot") == "1"
          kexec = ::Bootloader::Kexec.new
          ret = kexec.prepare_environment
        else
          log.info "Installation started with kexec_reboot set 0"
        end

        # (bnc #381192) don't use it if kexec is used
        # update calling onetime boot bnc #339024
        if !ret
          retcode = Yast::Bootloader.FlagOnetimeBoot(Yast::Bootloader.getDefaultSection)
        end
      end

      retcode
    end

  private

    def update_mount
      return unless Yast::Mode.update

      cmd = <<-eos
targetdir=#{Yast::Installation.destdir}
if test ${targetdir} = / ; then echo targetdir is / ; exit 1 ; fi
grep -E \"^[^ ]+ ${targetdir}/dev \" < /proc/mounts
if test $? = 0
then
 echo targetdir ${targetdir} already mounted.
 exit 1
else
  mkdir -vp ${targetdir}/dev
  cp --preserve=all --recursive --remove-destination /lib/udev/devices/* ${targetdir}/dev
  mount -v --bind /dev ${targetdir}/dev
fi
eos
      out = Yast::WFM.Execute(Yast::Path.new(".local.bash_output"), cmd)
      log.error "unable to bind mount /dev in chroot" if out["exit"] != 0
      log.info "#{cmd}\n output: #{out}"
    end

    def set_boot_msg
      finish_ret = {}

      if Yast::Arch.s390
        reipl_client = "reipl_bootloader_finish"

        # Calling a special reIPL client
        # it returns a result map (keys: (boolean) different, (string) ipl_msg)

        if Yast::WFM.ClientExists(reipl_client)
          finish_ret = Yast::WFM.call(reipl_client)
          log.info "result of reipl_bootloader_finish #{finish_ret}"
        else
          log.error "No such client: #{reipl_client}"
        end
      end

      if Yast::Arch.s390 && finish_ret["different"]
        # reIPL message
        ipl_msg = finish_ret["ipl_msg"] || ""

        # TRANSLATORS: reboot message
        # %1 is replaced with additional message from reIPL
        Yast::Misc.boot_msg = Yast::Builtins.sformat(
          _(
            "\n" \
              "Your system will now shut down.%1\n" \
              "For details, read the related chapter \n" \
              "in the documentation. \n"
          ),
          ipl_msg
        )
      else
        # Final message after all packages from CD1 are installed
        # and we're ready to start (boot into) the installed system
        # Message that will be displayed along with information
        # how the boot loader was installed
        Yast::Misc.boot_msg = _("The system will reboot now...")
      end
    end
  end
end
