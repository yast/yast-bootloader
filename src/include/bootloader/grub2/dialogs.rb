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
      Yast.import "CWMTab"
      Yast.import "BootCommon"
      Yast.import "Stage"

      Yast.include include_target, "bootloader/grub2/options.rb"

      Yast.include include_target, "bootloader/grub/options.rb"

      # Cache for genericWidgets function
      @_grub2_widgets = nil
      @_grub2_efi_widgets = nil
    end

    def boot_code_tab
      lt = BootCommon.getLoaderType(false)

      {
        "id"           => "boot_code_tab",
        "header"       => _("Boot Code Options"),
        # if name is not included, that it is not displayed
        "widget_names" => lt == "grub2-efi" ? ["distributor"] :
          ["distributor", "activate", "generic_mbr"],
        "contents"     => VBox(
          VSpacing(1),
          MarginBox(1, 0.5, "distributor"),
          MarginBox(1, 0.5, Left("activate")),
          MarginBox(1, 0.5, Left("generic_mbr")),
          VStretch()
        )
      }
    end

    def kernel_tab
       {
        "id"           => "kernel_tab",
        "header"       => _("Kernel Parameters"),
        "widget_names" => ["vgamode", "append", "append_failsafe", "console"],
        "contents"      => VBox(
          VSpacing(1),
          MarginBox(1, 0.5, "vgamode"),
          MarginBox(1, 0.5, "append"),
          MarginBox(1, 0.5, "append_failsafe"),
          MarginBox(1, 0.5, "console"),
          VStretch()
        )
      }
    end

    def bootloader_tab
       {
        "id" => "bootloader_tab",
        "header" => _("Bootloader Options"),
        "widget_names" => ["default", "timeout", "password", "os_prober", "hiddenmenu"],
        "contents" => VBox(
          VSpacing(2),
          HBox(
            HSpacing(1),
            "timeout",
            HSpacing(1),
            Left(VBox( "os_prober", "hiddenmenu")),
            HSpacing(1)
          ),
          MarginBox(1, 1, "default"),
          MarginBox(1, 1, "password"),
          VStretch()
        )
      }
    end

    # Run dialog for loader installation details for Grub2
    # @return [Symbol] for wizard sequencer
    def Grub2LoaderDetailsDialog
      Builtins.y2milestone("Running Grub2 loader details dialog")
      widgets = Grub2Options()

      tabs = [ bootloader_tab, kernel_tab, boot_code_tab]

      tab_widget = CWMTab.CreateWidget({
        "tab_order"    => tabs.map{ |t| t["id"] },
        "tabs"         => Hash[tabs.map{|tab| [tab["id"], tab]}],
        "initial_tab"  => tabs.first["id"],
        "widget_descr" => widgets
      })

      widgets["tab"] = tab_widget
      caption = _("Boot Loader Options")
      CWM.ShowAndRun(
        {
          "widget_descr" => widgets,
          "widget_names" => ["tab"],
          "contents"     => VBox("tab"),
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
