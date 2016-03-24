require "bootloader/kexec"
require "bootloader/bootloader_factory"
require "installation/finish_client"

Yast.import "Arch"
Yast.import "Bootloader"
Yast.import "Linuxrc"
Yast.import "Misc"
Yast.import "Mode"

module Bootloader
  # Finish client for bootloader configuration
  class FinishClient < ::Installation::FinishClient
    include Yast::I18n

    BASH_PATH = Yast::Path.new(".target.bash_output")

    def initialize
      textdomain "bootloader"
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
      # message after first round of packet installation
      # now the installed system is run and more packages installed
      # just warn the user that the screen is going back to text mode
      # and yast2 will come up again.
      set_boot_msg

      bl_current = ::Bootloader::BootloaderFactory.current
      # we do nothing in upgrade unless we have to change bootloader
      if Yast::Mode.update && !bl_current.read? && !bl_current.proposed?
        return true
      end

      # we do not manage bootloader, so relax :)
      return true if bl_current.name == "none"

      # read one from system, so we do not overwrite changes done in rpm post install scripts
      ::Bootloader::BootloaderFactory.clear_cache
      system = ::Bootloader::BootloaderFactory.system
      system.read
      system.merge(bl_current)
      system.write

      # fate #303395: Use kexec to avoid booting between first and second stage
      # copy vmlinuz, initrd and flush kernel option into /var/lib/YaST2
      if Yast::Linuxrc.InstallInf("kexec_reboot") == "1"
        kexec = ::Bootloader::Kexec.new
        kexec.prepare_environment
      else
        log.info "Installation started with kexec_reboot set 0"
      end

      true
    end

  private

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
