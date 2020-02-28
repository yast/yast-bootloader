# frozen_string_literal: true

require "installation/proposal_client"
require "bootloader/exceptions"
require "bootloader/main_dialog"
require "bootloader/bootloader_factory"
require "bootloader/systeminfo"
require "yast2/popup"

Yast.import "BootArch"

module Bootloader
  # Proposal client for bootloader configuration
  # rubocop:disable Metrics/ClassLength
  class ProposalClient < ::Installation::ProposalClient
    # Error when during update media is booted by different technology than target system.
    class MismatchBootloader < RuntimeError
      include Yast::I18n

      def initialize(old_bootloader, new_bootloader)
        @old_bootloader = old_bootloader
        @new_bootloader = new_bootloader

        raise "Invalid old bootloader #{old_bootloader}" unless boot_map[old_bootloader]
        raise "Invalid new bootloader #{new_bootloader}" unless boot_map[new_bootloader]

        super("Mismatching bootloaders")
      end

      def boot_map
        textdomain "bootloader"

        {
          # TRANSLATORS: kind of boot. It is term for way how x86_64 can boot
          "grub2"     => _("Legacy BIOS boot"),
          # TRANSLATORS: kind of boot. It is term for way how x86_64 can boot
          "grub2-efi" => _("EFI boot")
        }
      end

      def user_message
        textdomain "bootloader"

        # TRANSLATORS: keep %{} intact. It will be replaced by kind of boot
        format(_(
                 "Cannot upgrade the bootloader because of a mismatch of the boot technology. " \
       "The upgraded system uses <i>%{old_boot}</i> while the installation medium " \
       "has been booted using <i>%{new_boot}</i>.<br><br>" \
       "This scenario is not supported, the upgraded system may not boot " \
       "or the upgrade process can fail later."
               ),
          old_boot: boot_map[@old_bootloader], new_boot: boot_map[@new_bootloader])
      end
    end

    include Yast::I18n
    include Yast::Logger

    def initialize
      Yast.import "UI"
      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "BootStorage"
      Yast.import "Bootloader"
      Yast.import "Installation"
      Yast.import "Mode"
      Yast.import "BootSupportCheck"
      Yast.import "Product"
      Yast.import "PackagesProposal"
    end

    PROPOSAL_LINKS = [
      "enable_boot_mbr",
      "disable_boot_mbr",
      "enable_boot_boot",
      "disable_boot_boot",
      "enable_secure_boot",
      "disable_secure_boot",
      "enable_trusted_boot",
      "disable_trusted_boot"
    ].freeze

    def make_proposal(attrs)
      make_proposal_raising(attrs)
    rescue ::Bootloader::NoRoot
      no_root_proposal
    rescue MismatchBootloader => e
      mismatch_bootloader_proposal(e)
    rescue ::Bootloader::BrokenConfiguration => e
      broken_configuration_proposal(e)
    end

    def ask_user(param)
      chosen_id = param["chosen_id"]
      result = :next
      log.info "ask user called with #{chosen_id}"

      # enable boot from MBR
      case chosen_id
      when *PROPOSAL_LINKS
        value = (chosen_id =~ /enable/) ? true : false
        option = chosen_id[/(enable|disable)_(.*)/, 2]
        single_click_action(option, value)
      else
        settings = export_settings
        result = ::Bootloader::MainDialog.new.run_auto
        if result == :next
          Yast::Bootloader.proposed_cfg_changed = true
        elsif settings
          Yast::Bootloader.Import(settings)
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

    # make proposal without handling of exceptions
    def make_proposal_raising(attrs)
      if Yast::BootStorage.boot_filesystem.is?(:nfs)
        ::Bootloader::BootloaderFactory.current_name = "none"
        return construct_proposal_map
      end
      force_reset = attrs["force_reset"]
      storage_read = Yast::BootStorage.storage_read?
      storage_changed = Yast::BootStorage.storage_changed?
      log.info "Storage changed: #{storage_changed} force_reset #{force_reset}."
      log.info "Storage read previously #{storage_read.inspect}"
      # clear storage-ng devices cache otherwise it crashes (bsc#1071931)
      Yast::BootStorage.reset_disks if storage_changed

      if reset_needed?(force_reset, storage_changed && storage_read)
        # force re-calculation of bootloader proposal
        # this deletes any internally cached values, a new proposal will
        # not be partially based on old data now any more
        log.info "Recalculation of bootloader configuration"
        Yast::Bootloader.Reset
      end

      if Yast::Mode.update
        return { "raw_proposal" => [_("do not change")] } unless propose_for_update(force_reset)
      elsif Yast::Bootloader.proposed_cfg_changed
        # do nothing as user already modify it
      else
        # in installation always propose missing stuff
        # current below use proposed value if not already set
        # If set, then use same bootloader, but propose it again
        bl = ::Bootloader::BootloaderFactory.current
        bl.propose
      end

      update_required_packages

      construct_proposal_map
    end

    # returns if proposal should be reseted
    # logic in this condition:
    # when reset is forced or user do not modify proposal, reset proposal,
    # but only when not using auto_mode
    # But if storage changed, always repropose as it can be very wrong.
    def reset_needed?(force_reset, storage_changed)
      log.info "reset_needed? force_reset: #{force_reset} storage_changed: #{storage_changed}" \
        "auto mode: #{Yast::Mode.auto} cfg_changed #{Yast::Bootloader.proposed_cfg_changed}"
      return true if storage_changed
      return false if Yast::Mode.autoinst || Yast::Mode.autoupgrade
      return true if force_reset
      # reset when user does not do any change and not in update
      return true if !Yast::Mode.update && !Yast::Bootloader.proposed_cfg_changed

      false
    end

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

      if grub2_update?(current_bl)
        log.info "update of grub2, do not repropose"
        Yast::Bootloader.ReadOrProposeIfNeeded
      elsif old_bootloader == "none"
        log.info "Bootloader not configured, do not repropose"
        # blRead just exits for none bootloader
        ::Bootloader::BootloaderFactory.current_name = "none"
        ::Bootloader::BootloaderFactory.current.read

        return false
      # old one is grub2, but mismatch of EFI and non-EFI (bsc#1081355)
      elsif old_bootloader =~ /grub2/ && old_bootloader != current_bl.name
        raise MismatchBootloader.new(old_bootloader, current_bl.name)
      elsif !current_bl.proposed? || force_reset
        # Repropose the type. A regular Reset/Propose is not enough.
        # For more details see bnc#872081
        Yast::Bootloader.Reset
        ::Bootloader::BootloaderFactory.clear_cache
        proposed = ::Bootloader::BootloaderFactory.proposed
        proposed.propose
        ::Bootloader::BootloaderFactory.current = proposed
      end

      true
    end

    def grub2_update?(current_bl)
      [current_bl.name].include?(old_bootloader) &&
        !current_bl.proposed? &&
        !Yast::Bootloader.proposed_cfg_changed
    end

    def construct_proposal_map
      ret = {}

      ret["links"] = PROPOSAL_LINKS # use always possible links even if it maybe not used
      ret["raw_proposal"] = Yast::Bootloader.Summary
      ret["label_proposal"] = Yast::Bootloader.Summary(simple_mode: true)

      # support diskless client (FATE#300779)
      if Yast::BootStorage.boot_filesystem.is?(:nfs)
        log.info "Boot partition is nfs type, bootloader will not be installed."
        return ret
      end

      handle_errors(ret)

      ret
    end

    # Result of {#make_proposal} if a {Bootloader::NoRoot} exception is raised
    # while calculating the proposal
    #
    # @return [Hash]
    def no_root_proposal
      {
        "label_proposal" => [],
        "warning_level"  => :fatal,
        "warning"        => _("Cannot detect device mounted as root. Please check partitioning.")
      }
    end

    # Result of {#make_proposal} if a {Bootloader::BrokenConfiguration} exception
    # is raised while calculating the proposal
    #
    # @param err [Bootloader::BrokenConfiguration] raised exception
    # @return [Hash]
    def broken_configuration_proposal(err)
      {
        "label_proposal" => [],
        "warning_level"  => :error,
        # TRANSLATORS: %s is a string containing the technical details of the error
        "warning"        => _(
          "Error reading the bootloader configuration files. " \
          "Please open the booting options to fix it. Details: %s"
        ) % err.reason
      }
    end

    # Result of {#make_proposal} if a {Bootloader::MismatchBootloader} exception
    # is raised while calculating the proposal
    #
    # @param err [Bootloader::MismatchBootloader] raised exception
    # @return [Hash]
    def mismatch_bootloader_proposal(err)
      {
        "label_proposal" => [],
        "warning_level"  => :warning,
        "warning"        => err.user_message
      }
    end

    # Settings from the system being upgraded
    #
    # If the configuration is broken, this method simply returns nil without
    # user interaction. The circumstance has already been notified via the
    # standard warning mechanism of the proposal and the user will be asked
    # about what to do when opening the main configuration dialog.
    #
    # We don't need to handle the same problem for a third time.
    #
    # @return [Hash, nil] nil if the existing configuration is broken
    def export_settings
      Yast::Bootloader.Export
    rescue ::Bootloader::BrokenConfiguration
      nil
    end

    # Add to argument proposal map all errors detected by proposal
    # @return modified parameter
    def handle_errors(ret)
      current_bl = ::Bootloader::BootloaderFactory.current
      if current_bl.name == "none"
        log.error "No bootloader selected"
        ret["warning_level"] = :warning
        # warning text in the summary richtext
        ret["warning"] = _(
          "No boot loader is selected for installation. Your system might not be bootable."
        )
        return
      end

      if !Yast::BootStorage.bootloader_installable?
        ret["warning_level"] = :error
        ret["warning"] = _(
          "Because of the partitioning, the bootloader cannot be installed properly"
        )
        return
      end

      if !Yast::BootSupportCheck.SystemSupported
        ret["warning_level"] = :error
        ret["warning"] = Yast::BootSupportCheck.StringProblems
        return
      end

      nil
    end

    def single_click_action(option, value)
      bootloader = ::Bootloader::BootloaderFactory.current

      log.info "single_click_action: option #{option}, value #{value.inspect}"

      case option
      when "boot_mbr", "boot_boot"
        stage1 = bootloader.stage1
        devices = (option == "boot_mbr") ? stage1.boot_disk_names : stage1.boot_partition_names
        log.info "single_click_action: devices #{devices}"
        devices.each do |device|
          value ? stage1.add_udev_device(device) : stage1.remove_device(device)
        end
      when "trusted_boot"
        ::Bootloader::BootloaderFactory.current.trusted_boot = value
      when "secure_boot"
        ::Bootloader::BootloaderFactory.current.secure_boot = value
        if value && Yast::Arch.s390
          Yast2::Popup.show(
            _(
              "Make sure to also enable Secure Boot in the HMC.\n\n" \
              "Otherwise this system will not boot."
            ),
            headline: :warning, buttons: :ok
          )
        end
      end

      Yast::Bootloader.proposed_cfg_changed = true
    end

    def update_required_packages
      bl = ::Bootloader::BootloaderFactory.current
      bootloader_resolvables = Yast::PackagesProposal.GetResolvables("yast2-bootloader", :package)
      log.info "proposed packages to install #{bl.packages}"
      Yast::PackagesProposal.RemoveResolvables("yast2-bootloader", :package, bootloader_resolvables)
      Yast::PackagesProposal.AddResolvables("yast2-bootloader", :package, bl.packages)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
