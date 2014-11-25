# encoding: utf-8

# Module:		bootloader_proposal.ycp
#
# $Id$
#
# Author:		Klaus Kaempf <kkaempf@suse.de>
#
# Purpose:		Proposal function dispatcher - bootloader.
#
#			See also file proposal-API.txt for details.
module Yast
  class BootloaderProposalClient < Client
    def main
      Yast.import "UI"
      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "BootCommon"
      Yast.import "Bootloader"
      Yast.import "Installation"
      Yast.import "Storage"
      Yast.import "Mode"
      Yast.import "BootSupportCheck"

      Yast.include self, "bootloader/routines/wizards.rb"

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      # This will be called every time we enter the proposal widget. Here we can
      # return cached data, but when force_reset is set, we must create a new
      # proposal based on freshly discovered data (ie. from Storage:: and
      # perl-Bootloader (etc.?)).
      if @func == "MakeProposal"
        @force_reset = Ops.get_boolean(@param, "force_reset", false)
        @language_changed = Ops.get_boolean(@param, "language_changed", false)

        if @force_reset && !Mode.autoinst && !Mode.autoupgrade
          # force re-calculation of bootloader proposal
          # this deletes any internally cached values, a new proposal will
          # not be partially based on old data now any more
          Builtins.y2milestone(
            "Recalculation of bootloader configuration forced"
          )
          Bootloader.Reset
        end

        # proposal not changed by user so repropose it from scratch
        if !Bootloader.proposed_cfg_changed && !Mode.autoinst && !Mode.autoupgrade
          Builtins.y2milestone "Proposal not modified, so repropose from scratch"
          Bootloader.ResetEx(false)
        end

        if Mode.update
          if ["grub2", "grub2-efi"].include? old_bootloader
            Builtins.y2milestone "update of grub2, do not repropose"
            if !BootCommon.was_read || @force_reset
              # blRead(reread, avoid_reading_device_map)
              Bootloader.blRead(true, true)
              BootCommon.was_read = true
            end
          else
            if !BootCommon.was_proposed || @force_reset
              # Repropose the type. A regular Reset/Propose is not enough.
              # For more details see bnc#872081
              BootCommon.setLoaderType(nil)
              Bootloader.Reset
              Bootloader.Propose
            end
          end
        else
          # in installation always propose missing stuff
          Bootloader.Propose
        end

        if Bootloader.getLoaderType == "grub2"
          @ret["links"] = [
            "enable_boot_mbr",
            "disable_boot_mbr",
            "enable_boot_root",
            "disable_boot_root",
            "enable_boot_boot",
            "disable_boot_boot"
          ]
        end

        # to make sure packages will get installed
        BootCommon.setLoaderType(BootCommon.getLoaderType(false))

        @ret["raw_proposal"] = Bootloader.Summary

        # F#300779 - Install diskless client (NFS-root)
        # kokso:  bootloader will not be installed
        @device = BootCommon.getBootDisk
        if @device == "/dev/nfs"
          Builtins.y2milestone(
            "bootlader_proposal::MakeProposal -> Boot partition is nfs type, bootloader will not be installed."
          )
          Builtins.y2milestone("Type of BootPartitionDevice: %1", @device)
          return deep_copy(@ret)
        end
        Builtins.y2milestone("Type of BootPartitionDevice: %1", @device)

        # F#300779 - end

        if Bootloader.getLoaderType == ""
          Builtins.y2error("No bootloader selected")
          @ret = Builtins.add(@ret, "warning_level", :error)
          # warning text in the summary richtext
          @ret = Builtins.add(
            @ret,
            "warning",
            _(
              "No boot loader is selected for installation. Your system might not be bootable."
            )
          )
        end

        if !BootCommon.BootloaderInstallable
          @ret = {
            "warning_level" => :error,
            # error in the proposal
            "warning"       => _(
              "Because of the partitioning, the bootloader cannot be installed properly"
            )
          }
        end

        if !BootSupportCheck.SystemSupported
          @ret = Convert.convert(
            Builtins.union(
              @ret,
              
              "warning_level" => :error,
              "warning"       => BootSupportCheck.StringProblems,
              "raw_proposal"  => Bootloader.Summary
              
            ),
            :from => "map",
            :to   => "map <string, any>"
          )
        end

        # cache the values
        BootCommon.cached_settings_base_data_change_time = Storage.GetTargetChangeTime(
        )
      # This is a request to start some dialog and interact with the user to set
      # up the Bootloader setting. Called when the user presses the link to set
      # up the Bootloader.
      elsif @func == "AskUser"
        @chosen_id = Ops.get(@param, "chosen_id")
        @result = :next
        Builtins.y2milestone(
          "Bootloader wanted to change with id %1",
          @chosen_id
        )

        # enable boot from MBR
        if @chosen_id == "enable_boot_mbr"
          Builtins.y2milestone("Boot from MBR enabled by a single-click")
          Ops.set(BootCommon.globals, "boot_mbr", "true")
          Bootloader.proposed_cfg_changed = true
        # disable boot from MBR
        elsif @chosen_id == "disable_boot_mbr"
          Builtins.y2milestone("Boot from MBR disabled by a single-click")
          Ops.set(BootCommon.globals, "boot_mbr", "false")
          Bootloader.proposed_cfg_changed = true
        # enable boot from /boot
        elsif @chosen_id == "enable_boot_boot"
          Builtins.y2milestone("Boot from /boot enabled by a single-click")
          Ops.set(BootCommon.globals, "boot_boot", "true")
          Bootloader.proposed_cfg_changed = true
        # disable boot from /boot
        elsif @chosen_id == "disable_boot_boot"
          Builtins.y2milestone("Boot from /boot disabled by a single-click")
          Ops.set(BootCommon.globals, "boot_boot", "false")
          Bootloader.proposed_cfg_changed = true
        # enable boot from /
        elsif @chosen_id == "enable_boot_root"
          Builtins.y2milestone("Boot from / enabled by a single-click")
          Ops.set(BootCommon.globals, "boot_root", "true")
          Bootloader.proposed_cfg_changed = true
        # disable boot from /
        elsif @chosen_id == "disable_boot_root"
          Builtins.y2milestone("Boot from / disabled by a single-click")
          Ops.set(BootCommon.globals, "boot_root", "false")
          Bootloader.proposed_cfg_changed = true
        else
          @has_next = Ops.get_boolean(@param, "has_next", false)

          @settings = Bootloader.Export
          # don't ask for abort confirm if nothing was changed (#29496)
          BootCommon.changed = false
          @result = BootloaderAutoSequence()
          # set to true, simply because must be saved during installation
          BootCommon.changed = true
          if @result != :next
            Bootloader.Import(
              Convert.convert(
                @settings,
                :from => "map",
                :to   => "map <string, any>"
              )
            )
          else
            Bootloader.proposed_cfg_changed = true
          end
        end
        # Fill return map
        Ops.set(@ret, "workflow_sequence", @result)
      # This describes the "active" parts of the Bootloader proposal section.
      elsif @func == "Description"
        # Fill return map.
        #
        # Static values do just nicely here, no need to call a function.

        @ret = {
          # proposal part - bootloader label
          "rich_text_title" => _("Booting"),
          # menubutton entry
          "menu_title"      => _("&Booting"),
          "id"              => "bootloader_stuff"
        }
      # Before the system is installed there is no place to write to yet. This
      # code is not called. The bootloader will be installed later during
      # inst_finish.
      elsif @func == "Write"
        @succ = Bootloader.Write
        @ret = { "success" => @succ }
      end

      deep_copy(@ret)
    end

  private

    BOOT_SYSCONFIG_PATH = "/etc/sysconfig/bootloader"
    # read bootloader from /mnt as SCR is not yet switched in proposal
    # phase of update (bnc#874646)
    def old_bootloader
      target_boot_sysconfig_path = ::File.join(Installation.destdir, BOOT_SYSCONFIG_PATH)
      return nil unless ::File.exist? target_boot_sysconfig_path

      boot_sysconfig = ::File.read target_boot_sysconfig_path
      old_bootloader = boot_sysconfig.lines.grep(/^\s*LOADER_TYPE/)
      Builtins.y2milestone "bootloader entry #{old_bootloader.inspect}"
      retur nil if old_bootloader.empty?

      # get value from entry
      old_bootloader.last.sub(/^.*=\s*(\S*).*/,"\\1").delete('"')
    end
  end unless defined? Yast::BootloaderProposalClient
end

Yast::BootloaderProposalClient.new.main
