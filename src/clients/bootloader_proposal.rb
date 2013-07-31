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
      Yast.import "GfxMenu"
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

        # use the cache if possible
        # if not asked to recreate and we have a cached proposal and
        if false && !@force_reset && Bootloader.cached_proposal != nil &&
            # has the configuration been changed?
            Bootloader.cached_settings == Bootloader.Export &&
            # has the partitioning been changed?
            # This is correct as long as the proposal is only dependent on the
            # settings in Storage. AFAICT all information relevant to a
            # proposal in yast2-bootloader comes from yast2-storage. Even the
            # information from perl-Bootloader only depends on the settings in
            # Storage or libstorage. So this should be OK. At this point all
            # changes relevant to the yast2-bootloader settings are made
            # through Storage, so the change time of Storage data should be
            # sufficient.
            BootCommon.cached_settings_base_data_change_time ==
              Storage.GetTargetChangeTime
          # FIXME: has the software selection changed?: esp. has the
          # Xen pattern been activated ? then we'd have to make the
          # proposal again.
          Builtins.y2milestone("Using cached proposal")
          return deep_copy(Bootloader.cached_proposal)
        end

        if @force_reset && !Mode.autoinst
          # force re-calculation of bootloader proposal
          # this deletes any internally cached values, a new proposal will
          # not be partially based on old data now any more
          Builtins.y2milestone(
            "Recalculation of bootloader configuration forced"
          )
          Bootloader.Reset
        end

        if !Bootloader.proposed_cfg_changed && !Mode.autoinst
          Builtins.y2milestone("Cfg not changed before, recreating")
          Bootloader.ResetEx(false)
          BootCommon.setLoaderType(nil)
        end

        if Bootloader.getLoaderType == "grub"
          Yast.import "BootGRUB"
          # merge_level == `main means: merge only the "default" key(s?) of
          # a "foreign" grub configuration from a different configuration
          # into our configuration
          BootGRUB.merge_level = :main
          Bootloader.Propose


          BootGRUB.merge_level = :none

          Ops.set(
            @ret,
            "links",
            [
              "enable_boot_mbr",
              "disable_boot_mbr",
              "enable_boot_root",
              "disable_boot_root",
              "enable_boot_boot",
              "disable_boot_boot"
            ]
          )
        elsif Bootloader.getLoaderType == "grub2"
          if !Bootloader.proposed_cfg_changed && !Mode.autoinst
            Bootloader.blRead(true, true)
            BootCommon.was_read = true
          end

          Bootloader.Propose

          Ops.set(
            @ret,
            "links",
            [
              "enable_boot_mbr",
              "disable_boot_mbr",
              "enable_boot_root",
              "disable_boot_root",
              "enable_boot_boot",
              "disable_boot_boot"
            ]
          )
        elsif Bootloader.getLoaderType == "grub2-efi"
          if !Bootloader.proposed_cfg_changed && !Mode.autoinst
            Bootloader.blRead(true, true)
            BootCommon.was_read = true
          end

          Bootloader.Propose
        else
          Bootloader.Propose
        end
        # to make sure packages will get installed
        BootCommon.setLoaderType(BootCommon.getLoaderType(false))

        Ops.set(@ret, "raw_proposal", Bootloader.Summary)


        if Bootloader.getLoaderType == "grub"
          @max_end = 128

          if Ops.greater_than(
              BootSupportCheck.EndOfBootOrRootPartition,
              Ops.multiply(@max_end, 1073741824)
            )
            @ret = Builtins.add(@ret, "warning_level", :warning)
            # warning text in the summary richtext
            @ret = Builtins.add(
              @ret,
              "warning",
              Builtins.sformat(
                _(
                  "The bootloader is installed on a partition that does not lie entirely below %1 GB. The system might not boot if BIOS support only lba24 (result is error 18 during install grub MBR)."
                ),
                @max_end
              )
            )
          end
        end

        if Bootloader.getLoaderType == "grub"
          Yast.import "BootGRUB"
          if BootGRUB.CheckDeviceMap
            @ret = Convert.convert(
              Builtins.union(
                @ret,
                {
                  "warning_level" => :blocker,
                  "warning"       => Ops.add(
                    Ops.get_string(@ret, "warning", ""),
                    _(
                      "Configure a valid boot loader location before continuing.<br/>\n" +
                        "The device map includes more than 8 devices and the boot device is out of range.\n" +
                        "The range is limited by BIOS to the first 8 devices. Adjust BIOS boot order ( or if it already set, then correct order in bootloader configuration)"
                    )
                  )
                }
              ),
              :from => "map",
              :to   => "map <string, any>"
            )
          end
        end

        #F#300779 - Install diskless client (NFS-root)
        #kokso:  bootloader will not be installed
        @device = BootCommon.getBootDisk
        if @device == "/dev/nfs"
          Builtins.y2milestone(
            "bootlader_proposal::MakeProposal -> Boot partition is nfs type, bootloader will not be installed."
          )
          Builtins.y2milestone("Type of BootPartitionDevice: %1", @device)
          return deep_copy(@ret)
        end
        Builtins.y2milestone("Type of BootPartitionDevice: %1", @device)

        #F#300779 - end

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

        if Bootloader.getLoaderType == "lilo"
          Builtins.y2error("LILO bootloader selected")
          @ret = Builtins.add(@ret, "warning_level", :error)
          # warning text in the summary richtext
          @ret = Builtins.add(
            @ret,
            "warning",
            _("The LILO is not supported now.")
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
        elsif Bootloader.getLoaderType == "ppc"
          if Arch.board_chrp
            if Ops.get(BootCommon.globals, "activate", "false") == "false"
              @ret = Convert.convert(
                Builtins.union(
                  @ret,
                  {
                    "warning_level" => :error,
                    "warning"       => _(
                      "The selected boot path will not be activated for your installation. Your system may not be bootable."
                    )
                  }
                ),
                :from => "map",
                :to   => "map <string, any>"
              )
            end
          end

          if Arch.board_mac_new
            if BootCommon.loader_device == ""
              @ret = Convert.convert(
                Builtins.union(
                  @ret,
                  {
                    "warning_level" => :blocker,
                    "warning"       => Ops.add(
                      Ops.get_string(@ret, "warning", ""),
                      _(
                        "Configure a valid boot loader location before continuing.<br>\nIn case that no selection can be made it may be necessary to create a small primary Apple HFS partition."
                      )
                    )
                  }
                ),
                :from => "map",
                :to   => "map <string, any>"
              )
            end
          end


          if Arch.board_iseries
            # FIXME: handle consistency test for iseries configuration
            # currently: none
            Builtins.y2debug(
              "No consistency check implemented for iSeries boot configuration"
            )
          else
            # FIXME: better eliminate use of loader_device in the
            # future, no one knows what it is for
            if BootCommon.loader_device == ""
              @ret = Convert.convert(
                Builtins.union(
                  @ret,
                  {
                    "warning_level" => :blocker,
                    "warning"       => Ops.add(
                      Ops.get_string(@ret, "warning", ""),
                      _(
                        "Configure a valid boot loader location before continuing.<br>\nIn case that no selection can be made it may be necessary to create a PReP Boot partition."
                      )
                    )
                  }
                ),
                :from => "map",
                :to   => "map <string, any>"
              )
            end
          end
        end

        if !BootSupportCheck.SystemSupported
          @ret = Convert.convert(
            Builtins.union(
              @ret,
              {
                "warning_level" => :error,
                "warning"       => BootSupportCheck.StringProblems,
                "raw_proposal"  => Bootloader.Summary
              }
            ),
            :from => "map",
            :to   => "map <string, any>"
          )
        end

        # cache the values
        Bootloader.cached_settings = Bootloader.Export
        BootCommon.cached_settings_base_data_change_time = Storage.GetTargetChangeTime(
        )
        Bootloader.cached_proposal = deep_copy(@ret)
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
      # update GfxMenu texts after language was changed
      elsif @func == "UpdateGfxMenu"
        GfxMenu.Update
      end

      deep_copy(@ret)
    end
  end
end

Yast::BootloaderProposalClient.new.main
