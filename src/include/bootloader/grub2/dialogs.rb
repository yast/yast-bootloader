# encoding: utf-8

# File:
#      include/bootloader/grub2/dialogs.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Dialogs for configuraion i386-specific functions
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id: dialogs.ycp 56563 2009-04-02 08:41:25Z jreidinger $
#
module Yast
  module BootloaderGrub2DialogsInclude
    def initialize_bootloader_grub2_dialogs(include_target)
      Yast.import "UI"

      textdomain "bootloader"


      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "CWM"
      Yast.import "BootCommon"
      Yast.import "Stage"

      Yast.include include_target, "bootloader/grub2/options.rb"

      Yast.include include_target, "bootloader/grub/options.rb"

      # Cache for genericWidgets function
      @_grub2_widgets = nil
      @_grub2_efi_widgets = nil
    end

    # Run dialog for loader installation details for Grub2
    # @return [Symbol] for wizard sequencer
    def Grub2LoaderDetailsDialog
      Builtins.y2milestone("Running Grub2 loader details dialog")
      contents = HBox(
        HSpacing(2),
        VBox(
          VStretch(),
          HBox(HSquash("distributor"), "hiddenmenu", "os_prober", HStretch()),
          HBox("activate", "generic_mbr", HStretch()),
          HBox(HSquash("timeout"), "vgamode", HStretch()),
          Left("append"),
          Left("append_failsafe"),
          Left("default"),
          Left("console"),
          Left("gfxterm"),
          VStretch()
        ),
        HSpacing(2)
      )

      lt = BootCommon.getLoaderType(false)
      widget_names = lt == "grub2-efi" ?
        [
          "distributor",
          "hiddenmenu",
          "os_prober",
          "timeout",
          "append",
          "append_failsafe",
          "console",
          "default",
          "vgamode"
        ] :
        [
          "distributor",
          "activate",
          "generic_mbr",
          "hiddenmenu",
          "os_prober",
          "timeout",
          "append",
          "append_failsafe",
          "console",
          "default",
          "vgamode"
        ]

      caption = _("Boot Loader Options")
      CWM.ShowAndRun(
        {
          "widget_descr" => Grub2Options(),
          "widget_names" => widget_names,
          "contents"     => contents,
          "caption"      => caption,
          "back_button"  => Label.BackButton,
          "abort_button" => Label.CancelButton,
          "next_button"  => Label.OKButton
        }
      )
    end

    def InitSecureBootWidget(widget)
      sb = BootCommon.getSystemSecureBootStatus(false)
      UI.ChangeWidget(Id("secure_boot"), :Value, sb)

      nil
    end
    def HandleSecureBootWidget(widget, event)
      event = deep_copy(event)
      nil
    end
    def StoreSecureBootWidget(widget, event)
      event = deep_copy(event)
      sb = Convert.to_boolean(UI.QueryWidget(Id("secure_boot"), :Value))
      BootCommon.setSystemSecureBootStatus(sb)

      nil
    end
    def HelpSecureBootWidget
      ret = "Tick to enable UEFI Secure Boot\n"
      ret
    end

    def grub2SecureBootWidget
      contents = VBox(
        Frame(
          _("Secure Boot"),
          VBox(
            HBox(
              HSpacing(1),
              VBox(
                Left(
                  CheckBox(Id("secure_boot"), _("Enable &Secure Boot Support"))
                ),
                VStretch()
              )
            )
          )
        ),
        VStretch()
      )

      {
        "widget"        => :custom,
        "custom_widget" => contents,
        "init"          => fun_ref(
          method(:InitSecureBootWidget),
          "void (string)"
        ),
        "handle"        => fun_ref(
          method(:HandleSecureBootWidget),
          "symbol (string, map)"
        ),
        "store"         => fun_ref(
          method(:StoreSecureBootWidget),
          "void (string, map)"
        ),
        "help"          => HelpSecureBootWidget()
      }
    end

    # Run dialog to adjust installation on i386 and AMD64
    # @return [Symbol] for wizard sequencer
    def Grub2InstallDetailsDialog
      contents = HBox(
        HStretch(),
        VBox(VStretch(), Frame(_("Disk Order"), "disks_order"), VStretch()),
        HStretch()
      )

      CWM.ShowAndRun(
        {
          "widget_descr" => { "disks_order" => DisksOrderWidget() },
          "widget_names" => ["disks_order"],
          "contents"     => contents,
          "caption"      => _("Disk order settings"),
          "back_button"  => Label.BackButton,
          "abort_button" => Label.CancelButton,
          "next_button"  => Label.OKButton
        }
      )
    end

    # Get generic widgets
    # @return a map describing all generic widgets
    def grub2Widgets
      if @_grub2_widgets == nil
        @_grub2_widgets = { "loader_location" => grubBootLoaderLocationWidget }
      end
      deep_copy(@_grub2_widgets)
    end

    def grub2efiWidgets
      if Arch.x86_64
        if @_grub2_efi_widgets == nil
          @_grub2_efi_widgets = { "loader_location" => grub2SecureBootWidget }
        end
      end

      deep_copy(@_grub2_efi_widgets)
    end
  end
end
