# encoding: utf-8

# File:
#      modules/BootGRUB2.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for GRUB2 configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id: BootGRUB.ycp 63508 2011-03-04 12:53:27Z jreidinger $
#

require "yast"
require "bootloader/boot_record_backup"
require "bootloader/disk_change_detector"
require "bootloader/stage1"

module Yast
  module BootloaderGrub2MiscInclude
    include Yast::Logger

    def initialize_bootloader_grub2_misc(_include_target)
      textdomain "bootloader"
      Yast.import "Arch"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Map"
      Yast.import "Mode"
      Yast.import "PackageSystem"
      Yast.import "Partitions"
      Yast.import "Storage"
      Yast.import "StorageDevices"
    end

    # --------------------------------------------------------------
    # --------------------------------------------------------------
    # LocationProposal() and related stuff (taken from routines/lilolike.ycp)

    # Set "boot_*" flags in the globals map according to the boot device selected
    # with parameter selected_location. Only a single boot device can be selected
    # with this function. The function cannot be used to set a custom boot device.
    # It will always be deleted.
    #
    # FIXME: `mbr_md is probably unneeded; AFA we can see, this decision is
    # automatic anyway and perl-Bootloader should be able to make it without help
    # from the user or the proposal.
    #
    # @param [Symbol] selected_location symbol one of `boot `root `mbr `extended `mbr_md `none
    def reset_bootloader_device
      # first, default to all off:
      ["boot_boot", "boot_root", "boot_mbr", "boot_extended"].each do |flag|
        BootCommon.globals[flag] = "false"
      end
      # need to remove the boot_custom key to switch this value off
      BootCommon.globals.delete("boot_custom")
    end

    # grub_ConfigureLocation()
    # Where to install the bootloader.
    # Returns the type of device where to install: one of `boot `root `mbr `extended `mbr_md
    # Also sets the boot_* keys in the internal global variable globals accordingly.
    #
    # @return [String] type of location proposed to bootloader
    def grub_ConfigureLocation
      ::Bootloader::Stage1.new.propose
    end

    def gpt_boot_disk?
      targets = BootCommon.GetBootloaderDevices
      boot_discs = targets.map { |d| Storage.GetDisk(Storage.GetTargetMap, d) }
      boot_discs.any? { |d| d["label"] == "gpt" }
    end

    # Detect "/boot", "/" (root), extended partition device and MBR disk device
    #
    # If no bootloader device has been set up yet (globals["boot_*"]), or the
    # first (FIXME(!)) device is not available as a boot partition, also call
    # grub_ConfigureLocation to configure globals["boot_*"] and set the
    # globals["activate"] and globals["generic_mbr"] flags if needed
    # all these settings are stored in internal variables
    def grub_DetectDisks
      location_reconfigure = BootStorage.detect_disks

      return if location_reconfigure == :ok
      # if already proposed, then empty location is intention of user
      return if location_reconfigure == :empty && BootCommon.was_proposed

      grub_ConfigureLocation
    end

    # Propose the boot loader location for grub
    #  - if no proposal has been made, collects the devices for "/", "/boot", MBR
    #    and makes a new proposal
    #  - if no device mapping exists, creates a device mapping
    #  - if the devices that were somehow (proposal, user interface) selected for
    #    bootloader installation do not match the current partitioning any more
    #    (e.g. "/boot" partition was selected but is not available anymore (and
    #    "/" did not move there), "/" was selected but has moved, etc.), then also
    #    re-collect the devices for "/", "/boot", MBR and make a new proposal
    def grub_LocationProposal
      log.info "globals: #{BootCommon.globals}"
      log.info "Mode #{Mode.mode}"
      no_boot_key = ["boot_boot", "boot_root", "boot_mbr", "boot_extended", "boot_custom"].none? do |k|
        BootCommon.globals[k]
      end
      if !BootCommon.was_proposed ||
          # During autoinstall, the autoyast profile must contain a bootloader
          # device specification (we currently really only support system
          # *cloning* with autoyast...). But as a convenience, and because
          # this kind of magic is available for empty globals and sections, we
          # propose a bootloader location if none was specified.
          # Note that "no bootloader device" can be specified by explicitly
          # setting this up, e.g. by setting one or all boot_* flags to
          # "false".
          (Mode.autoinst || Mode.autoupgrade) && no_boot_key
        grub_DetectDisks
        # check whether edd is loaded; if not: load it
        edd_loaded = SCR.Read(path(".proc.modules"))["edd"]
        log.info "edd loaded? #{edd_loaded.inspect}"
        if !edd_loaded
          command = "/sbin/modprobe edd"
          out = SCR.Execute(path(".target.bash_output"), command)
          log.info "Command '#{command}' output: #{out}"
        end
        redundant_devices = BootStorage.devices_for_redundant_boot
        BootCommon.globals["boot_md_mbr"] = redundant_devices.join(",") unless redundant_devices.empty?
      end
      log.info "(2) globals: #{BootCommon.globals}"

      # refresh device map
      if BootStorage.device_map.empty?  ||
          BootCommon.cached_settings_base_data_change_time !=
              Storage.GetTargetChangeTime &&
              # bnc#585824 - Bootloader doesn't use defined device map from autoyast
              !((Mode.autoinst || Mode.autoupgrade) &&
                BootCommon.cached_settings_base_data_change_time.nil?)
        BootStorage.device_map.propose
        BootCommon.InitializeLibrary(true, "grub2")
      end

      if !Mode.autoinst && !Mode.autoupgrade
        changes = ::Bootloader::DiskChangeDetector.new.changes
        if !changes.empty?
          log.info "Location change detected"
          if BootCommon.askLocationResetPopup(changes.join("\n"))
            reset_bootloader_device
            Builtins.y2milestone("Reconfiguring locations")
            grub_DetectDisks
          end
        end
      end

      nil
    end
  end
end
