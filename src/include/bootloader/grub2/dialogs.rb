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

      Yast.import "Arch"
      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "CWM"
      Yast.import "CWMTab"
      Yast.import "BootCommon"
      Yast.import "Stage"

      Yast.include include_target, "bootloader/grub2/options.rb"
      # some utils from misc are needed here
      Yast.include include_target, "bootloader/grub2/misc.rb"

      Yast.include include_target, "bootloader/grub/options.rb"

      # Cache for genericWidgets function
      @_grub2_widgets = nil
      @_grub2_efi_widgets = nil
    end

    def boot_code_tab
      lt = BootCommon.getLoaderType(false)

      legacy_intel = (Arch.x86_64 || Arch.i386) && lt != "grub2-efi"
      pmbr_available = lt == "grub2-efi" || (legacy_intel && gpt_boot_disk?)
      widget_names = ["distributor", "loader_type", "loader_location"]
      widget_names << "activate" << "generic_mbr" if legacy_intel
      widget_names << "inst_details" if legacy_intel || Arch.ppc
      widget_names << "pmbr" if pmbr_available

      {
        "id"           => "boot_code_tab",
        # Title in tab
        "header"       => _("Boot Code Options"),
        # if name is not included, that it is not displayed
        "widget_names" => widget_names,
        "contents"     => VBox(
          VSquash(
            HBox(
              Top(VBox(VSpacing(1), "loader_type")),
              Arch.s390 || Arch.aarch64 ? Empty() : "loader_location"
            )
          ),
          MarginBox(1, 0.5, "distributor"),
          MarginBox(1, 0.5, Left("activate")),
          MarginBox(1, 0.5, Left("generic_mbr")),
          MarginBox(1, 0.5, Left("pmbr")),
          MarginBox(1, 0.5, Left("inst_details")),
          VStretch()
        )
      }
    end

    def kernel_tab
      widgets = ["vgamode", "append", "console"]
      widgets.delete("console") if Arch.s390 # there is no console on s390 (bnc#868909)
      widgets.delete("vgamode") if Arch.s390 # there is no graphic adapter on s390 (bnc#874010)

      {
        "id"           => "kernel_tab",
        # Title in tab
        "header"       => _("Kernel Parameters"),
        "widget_names" => widgets,
        "contents"     => VBox(
          VSpacing(1),
          MarginBox(1, 0.5, "vgamode"),
          MarginBox(1, 0.5, "append"),
          MarginBox(1, 0.5, "console"),
          VStretch()
       )
      }
    end

    def bootloader_tab
      widgets = ["default", "timeout", "password", "os_prober", "hiddenmenu"]
      widgets.delete("os_prober") if Arch.s390 # there is no os prober on s390(bnc#868909)

      {
        "id"           => "bootloader_tab",
        # Title in tab
        "header"       => _("Bootloader Options"),
        "widget_names" => widgets,
        "contents"     => VBox(
          VSpacing(2),
          HBox(
            HSpacing(1),
            "timeout",
            HSpacing(1),
            VBox(
              Left("os_prober"),
              VSpacing(1),
              Left("hiddenmenu")
            ),
            HSpacing(1)
          ),
          VSpacing(1),
          MarginBox(1, 1, "default"),
          MarginBox(1, 1, "password"),
          VStretch()
       )
      }
    end

    def Grub2TabDescr
      tabs = [bootloader_tab, kernel_tab, boot_code_tab]

      Hash[tabs.map { |tab| [tab["id"], tab] }]
    end

    # Run dialog for loader installation details for Grub2
    # @return [Symbol] for wizard sequencer
    def Grub2LoaderDetailsDialog
      Builtins.y2milestone("Running Grub2 loader details dialog")
      widgets = Grub2Options()

      tabs = [bootloader_tab, kernel_tab, boot_code_tab]

      tab_widget = CWMTab.CreateWidget(
        "tab_order"    => tabs.map { |t| t["id"] },
        "tabs"         => Hash[tabs.map { |tab| [tab["id"], tab] }],
        "initial_tab"  => tabs.first["id"],
        "widget_descr" => widgets
      )

      widgets["tab"] = tab_widget
      # Window title
      caption = _("Boot Loader Options")
      CWM.ShowAndRun(

        "widget_descr" => widgets,
        "widget_names" => ["tab"],
        "contents"     => VBox("tab"),
        "caption"      => caption,
        "back_button"  => Label.BackButton,
        "abort_button" => Label.CancelButton,
        "next_button"  => Label.OKButton

      )
    end

    def InitSecureBootWidget(_widget)
      sb = BootCommon.getSystemSecureBootStatus(false)
      UI.ChangeWidget(Id("secure_boot"), :Value, sb)

      nil
    end

    def HandleSecureBootWidget(_widget, _event)
      nil
    end

    def StoreSecureBootWidget(_widget, _event)
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
        VSpacing(1),
        Frame(
          _("Secure Boot"),
          VBox(
            HBox(
              HSpacing(1),
              VBox(
                Left(
                  CheckBox(Id("secure_boot"), _("Enable &Secure Boot Support"))
                )
              )
            )
          )
        )
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

    def ppc_location_init(_widget)
      UI::ChangeWidget(
        Id("boot_custom_list"),
        :Value,
        BootCommon.globals["boot_custom"]
      )
    end

    def ppc_location_store(_widget, value)
      value = UI::QueryWidget(
        Id("boot_custom_list"),
        :Value
      )
      y2milestone("store boot custom #{value}")

      BootCommon.globals["boot_custom"] = value
    end

    def grub_on_ppc_location
      contents = VBox(
        VSpacing(1),
        ComboBox(
          Id("boot_custom_list"),
          # TRANSLATORS: place where boot code is installed
          _("Boot &Loader Location"),
          prep_partitions
        )
      )

      {
        # need custom to not break ui as intel one is quite complex so some
        # spacing is needed
        "widget"        => :custom,
        "custom_widget" => contents,
        "init"          => fun_ref(
          method(:ppc_location_init),
          "void (string)"
        ),
        "store"         => fun_ref(
          method(:ppc_location_store),
          "void (string, map)"
        ),
        # help text
        "help"          => _("Choose partition where is boot sequence installed.")
      }
    end

    # Get generic widgets
    # @return a map describing all generic widgets
    def grub2Widgets
      if @_grub2_widgets.nil?
        case Arch.architecture
        when "i386", "x86_64"
          @_grub2_widgets = { "loader_location" => grubBootLoaderLocationWidget }
        when /ppc/
          @_grub2_widgets = { "loader_location" => grub_on_ppc_location }
        when /s390/
          @_grub2_widgets = {} # no loader location for s390 as it is automatic
        else
          raise "unsuppoted architecture #{Arch.architecture}"
        end
        @_grub2_widgets.merge! Grub2Options()
      end
      deep_copy(@_grub2_widgets)
    end

    def grub2efiWidgets
      if @_grub2_efi_widgets.nil?
        if Arch.x86_64
          @_grub2_efi_widgets = { "loader_location" => grub2SecureBootWidget }
        else
          @_grub2_efi_widgets = {}
        end
        @_grub2_efi_widgets.merge! Grub2Options()
      end

      deep_copy(@_grub2_efi_widgets)
    end
  end
end
