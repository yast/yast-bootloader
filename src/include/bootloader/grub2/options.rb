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

require "bootloader/grub2pwd"

module Yast
  module BootloaderGrub2OptionsInclude
    def initialize_bootloader_grub2_options(include_target)
      textdomain "bootloader"

      Yast.import "Label"
      Yast.import "Initrd"

      Yast.include include_target, "bootloader/routines/common_options.rb"
      Yast.include include_target, "bootloader/grub/helps.rb"
      Yast.include include_target, "bootloader/grub2/helps.rb"

      @vga_modes = []
    end

    # Init function of widget
    # @param [String] widget any id of the widget
    def VgaModeInit(widget)
      @vga_modes = Initrd.VgaModes if Builtins.size(@vga_modes) == 0

      items = Builtins.maplist(@vga_modes) do |m|
        Item(
          Id(
            Builtins.sformat(
              "%1",
              Builtins.tohexstring(Ops.get_integer(m, "mode", 0))
            )
          ),
          # combo box item
          # %1 is X resolution (width) in pixels
          # %2 is Y resolution (height) in pixels
          # %3 is color depth (usually one of 8, 16, 24, 32)
          # %4 is the VGA mode ID (hexadecimal number)
          Builtins.sformat(
            _("%1x%2, %3 bits (mode %4)"),
            Ops.get_integer(m, "width", 0),
            Ops.get_integer(m, "height", 0),
            Ops.get_integer(m, "color", 0),
            Builtins.tohexstring(Ops.get_integer(m, "mode", 0))
          )
        )
      end
      items = Builtins.prepend(
        items,
        Item(Id("extended"), _("Standard 8-pixel font mode."))
      )
      # item of a combo box
      items = Builtins.prepend(items, Item(Id("normal"), _("Text Mode")))
      items = Builtins.prepend(items, Item(Id(""), _("Unspecified")))
      UI.ChangeWidget(Id(widget), :Items, items)
      InitGlobalStr(widget)

      nil
    end

    def DefaultEntryInit(widget)
      items = @sections.map { |s| Item(Id(s), s) }

      UI.ChangeWidget(Id(widget), :Items, items)
      InitGlobalStr(widget)
      nil
    end

    # Init function of widget
    # @param [String] widget any id of the widget
    def PMBRInit(widget)
      items = [
        # TRANSLATORS: set flag on disk
        Item(Id(:add), _("set")),
        # TRANSLATORS: remove flag from disk
        Item(Id(:remove), _("remove")),
        # TRANSLATORS: do not change flag on disk
        Item(Id(:nothing), _("do not change"))
      ]
      UI.ChangeWidget(Id(widget), :Items, items)
      value = BootCommon.pmbr_action || :nothing
      UI.ChangeWidget(Id(widget), :Value, value)
    end

    # Store function of a pmbr
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    def StorePMBR(widget, _event)
      value = UI.QueryWidget(Id(widget), :Value)
      value = nil if value == :nothing

      BootCommon.pmbr_action = value
    end
  end
end
