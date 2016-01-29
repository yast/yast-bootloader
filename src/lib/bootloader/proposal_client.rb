require "installation/proposal_client"
require "bootloader/main_dialog"
require "bootloader/bootloader_factory"

module Bootloader
  # Proposal client for bootloader configuration
  class ProposalClient < ::Installation::ProposalClient
    include Yast::I18n
    include Yast::Logger

    def initialize
      Yast.import "UI"
      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "BootStorage"
      Yast.import "Bootloader"
      Yast.import "Installation"
      Yast.import "Storage"
      Yast.import "Mode"
      Yast.import "BootSupportCheck"
      Yast.import "Product"
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

      construct_proposal_map
    end

    def ask_user(param)
      chosen_id = param["chosen_id"]
      result = :next
      log.info "ask user called with #{chosen_id}"

      # enable boot from MBR
      case chosen_id
      when *PROPOSAL_LINKS
        value = chosen_id =~ /enable/ ? true : false
        option = chosen_id[/(enable|disable)_boot_(.*)/, 2]
        single_click_action(option, value)
      else
        settings = Yast::Bootloader.Export
        result = ::Bootloader::MainDialog.new.run_auto
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
      current_bl = ::Bootloader::BootloaderFactory.current
      if ["grub2", "grub2-efi"].include?(old_bootloader) &&
          !current_bl.proposed? &&
          !Yast::Bootloader.proposed_cfg_changed
        log.info "update of grub2, do not repropose"
        return false
      elsif old_bootloader == "none"
        log.info "Bootloader not configured, do not repropose"
        # blRead just exits for none bootloader
        ::Bootloader::BootloaderFactory.current_name = "none"
        ::Bootloader::BootloaderFactory.current.read
      elsif !current_bl.proposed? || force_reset
        # Repropose the type. A regular Reset/Propose is not enough.
        # For more details see bnc#872081
        Yast::Bootloader.Reset
        Yast::Bootloader.Propose
      end

      true
    end

    def construct_proposal_map
      ret = {}

      ret["links"] = PROPOSAL_LINKS # use always possible links even if it maybe not used
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
      if ::Bootloader::BootloaderFactory.current.name == "none"
        log.error "No bootloader selected"
        ret["warning_level"] = :warning
        # warning text in the summary richtext
        ret["warning"] = _(
          "No boot loader is selected for installation. Your system might not be bootable."
        )
      end

      if !Yast::BootStorage.bootloader_installable?
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
      stage1 = ::Bootloader::BootloaderFactory.current.stage1
      locations = stage1.available_locations
      device = locations[option.to_sym] or raise "invalid option #{option}"
      log.info "single_click_action #{option} #{value.inspect} #{device}"

      value ? stage1.add_udev_device(device) : stage1.remove_device(device)

      Yast::Bootloader.proposed_cfg_changed = true
    end
  end
end
