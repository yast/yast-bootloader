require "installation/proposal_client"

module Bootloader
  # Proposal client for bootloader configuration
  class ProposalClient < ::Installation::ProposalClient
    include Yast::I18n

    def initialize
      Yast.import "UI"
      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Bootloader"
      Yast.import "Installation"
      Yast.import "Storage"
      Yast.import "Mode"
      Yast.import "BootSupportCheck"
      Yast.import "Product"

      Yast.include self, "bootloader/routines/wizards.rb"
    end

    PROPOSAL_LINKS = [
      "enable_boot_mbr",
      "disable_boot_mbr",
      "enable_boot_root",
      "disable_boot_root",
      "enable_boot_boot",
      "disable_boot_boot"
    ]

    def make_proposal(attrs)
      force_reset = attrs["force_reset"]
      auto_mode = Yast::Mode.autoinst || Yast::Mode.autoupgrade

      if (force_reset || !Yast::Bootloader.proposed_cfg_changed) &&
          !auto_mode
        # force re-calculation of bootloader proposal
        # this deletes any internally cached values, a new proposal will
        # not be partially based on old data now any more
        log.info "Recalculation of bootloader configuration"
        Yast::Bootloader.Reset
      end

      if Yast::Mode.update
        return { "raw_proposal" => [_("do not change")] } unless propose_for_update(force_reset)
      else
        # in installation always propose missing stuff
        Yast::Bootloader.Propose
      end

      # to make sure packages will get installed
      Yast::BootCommon.setLoaderType(Yast::BootCommon.getLoaderType(false))

      ret = construct_proposal_map

      # cache the values
      Yast::BootCommon.cached_settings_base_data_change_time = Yast::Storage.GetTargetChangeTime()

      ret
    end

    def ask_user(param)
      chosen_id = param["chosen_id"]
      result = :next

      # enable boot from MBR
      case chosen_id
      when *PROPOSAL_LINKS
        value = chosen_id =~ /enable/ ? "true" : "false"
        option = chosen_id[/(enable|disable)_(.*)/, 2]
        single_click_action(option, value)
      else
        settings = Yast::Bootloader.Export
        # don't ask for abort confirm if nothing was changed (#29496)
        Yast::BootCommon.changed = false
        result = BootloaderAutoSequence()
        # set to true, simply because must be saved during installation
        Yast::BootCommon.changed = true
        if result != :next
          Yast::Bootloader.Import(settings)
        else
          Yast::Bootloader.proposed_cfg_changed = true
        end
      end
      # Fill return map
      { "workflow_sequence" => result }
    end

    def description
      {
        # proposal part - bootloader label
        "rich_text_title" => _("Booting"),
        # menubutton entry
        "menu_title"      => _("&Booting"),
        "id"              => "bootloader_stuff"
      }
    end

  private

    BOOT_SYSCONFIG_PATH = "/etc/sysconfig/bootloader"
    # read bootloader from /mnt as SCR is not yet switched in proposal
    # phase of update (bnc#874646)
    def old_bootloader
      target_boot_sysconfig_path = ::File.join(Yast::Installation.destdir, BOOT_SYSCONFIG_PATH)
      return nil unless ::File.exist? target_boot_sysconfig_path

      boot_sysconfig = ::File.read target_boot_sysconfig_path
      old_bootloader = boot_sysconfig.lines.grep(/^\s*LOADER_TYPE/)
      log.info "bootloader entry #{old_bootloader.inspect}"
      return nil if old_bootloader.empty?

      # get value from entry
      old_bootloader.last.chomp.sub(/^.*=\s*(\S*).*/, "\\1").delete('"\'')
    end

    def propose_for_update(force_reset)
      if ["grub2", "grub2-efi"].include?(old_bootloader) &&
          !Yast::BootCommon.was_proposed &&
          !Yast::Bootloader.proposed_cfg_changed
        log.info "update of grub2, do not repropose"
        return false
      elsif old_bootloader == "none"
        log.info "Bootloader not configured, do not repropose"
        # blRead just exits for none bootloader
        Yast::BootCommon.was_read = true
      elsif !Yast::BootCommon.was_proposed || force_reset
        # Repropose the type. A regular Reset/Propose is not enough.
        # For more details see bnc#872081
        Yast::BootCommon.setLoaderType(nil)
        Yast::Bootloader.Reset
        Yast::Bootloader.Propose
      end

      true
    end

    def construct_proposal_map
      ret = {}

      ret["links"] = PROPOSAL_LINKS if Yast::Bootloader.getLoaderType == "grub2"
      ret["raw_proposal"] = Yast::Bootloader.Summary

      # F#300779 - Install diskless client (NFS-root)
      # kokso:  bootloader will not be installed
      device = Yast::BootStorage.disk_with_boot_partition
      log.info "Type of BootPartitionDevice: #{device}"
      if device == "/dev/nfs"
        log.info "Boot partition is nfs type, bootloader will not be installed."
        return ret
      end
      # F#300779 - end

      handle_errors(ret)

      ret
    end

    # Add to argument proposal map all errors detected by proposal
    # @return modified parameter
    def handle_errors(ret)
      if Yast::Bootloader.getLoaderType == "none"
        log.error "No bootloader selected"
        ret["warning_level"] = :warning
        # warning text in the summary richtext
        ret["warning"] = _(
          "No boot loader is selected for installation. Your system might not be bootable."
        )
      end

      if !Yast::BootCommon.BootloaderInstallable
        ret.merge!(
          "warning_level" => :error,
          # error in the proposal
          "warning"       => _(
            "Because of the partitioning, the bootloader cannot be installed properly"
          )
        )
      end

      if !Yast::BootSupportCheck.SystemSupported
        ret.merge!(
          "warning_level" => :error,
          "warning"       => Yast::BootSupportCheck.StringProblems
        )
      end

      ret
    end

    def single_click_action(option, value)
      log.info "option #{option} with value #{value} set by a single-click"
      Yast::BootCommon.globals[option] = value
      Yast::Bootloader.proposed_cfg_changed = true
    end
  end
end
