# encoding: utf-8

# File:
#      modules/BootELILO.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for ELILO configuration
#      and installation
#
# Authors:
#      Joachim Plack <jplack@suse.de>
#      Jiri Srain <jsrain@suse.cz>
#      Andreas Schwab <schwab@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id$
#
module Yast
  module BootloaderEliloWidgetsInclude
    def initialize_bootloader_elilo_widgets(include_target)
      textdomain "bootloader"

      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "BootCommon"
      Yast.include include_target, "bootloader/routines/popups.rb"



      # Cache for ppcWidgets function
      @_elilo_widgets = nil
    end

    # Bootloader target widget

    # Get widget term
    # @return widget term
    def getTargetWidget
      have_old = @old_efi_entry != nil && @old_efi_entry != ""

      widget = VBox(
        Frame(
          _("EFI Label"),
          HBox(
            HSpacing(1),
            VBox(
              VSpacing(1),
              Left(
                CheckBox(
                  Id(:create_entry),
                  Opt(:notify),
                  # check box
                  _("&Create EFI Entry")
                )
              ),
              Left(
                InputField(
                  Id(:location),
                  Opt(:hstretch),
                  # text entry label
                  _("&EFI Entry Name")
                )
              ),
              VStretch()
            )
          )
        )
      )
      deep_copy(widget)
    end

    # Init function of a popup
    # @param opt_id any option id
    # @param opt_key any option key
    def targetInit(widget)
      UI.ChangeWidget(Id(:create_entry), :Value, @create_efi_entry)
      UI.ChangeWidget(
        Id(:location),
        :Value,
        Ops.get(BootCommon.globals, "boot_efilabel", "")
      )
      UI.ChangeWidget(Id(:location), :Enabled, @create_efi_entry)

      nil
    end

    # Handle function of widget
    # @param opt_id any option id
    # @param opt_key any option key
    # @param [Hash] event map event that occured
    def targetHandle(widget, event)
      event = deep_copy(event)
      UI.ChangeWidget(
        Id(:location),
        :Enabled,
        UI.QueryWidget(Id(:create_entry), :Value)
      )
      nil
    end

    # Store function of a popup
    # @param opt_id any option id
    # @param opt_key any option key
    def targetStore(widget, event)
      event = deep_copy(event)
      Ops.set(
        BootCommon.globals,
        "boot_efilabel",
        Convert.to_string(UI.QueryWidget(Id(:location), :Value))
      )
      BootCommon.location_changed = true
      @create_efi_entry = Convert.to_boolean(
        UI.QueryWidget(Id(:create_entry), :Value)
      )

      nil
    end

    # Validate function of a popup
    # @param opt_id any option id
    # @param opt_key any option key
    # @param [Hash] event map event that caused validation
    # @return [Boolean] true if widget settings ok
    def targetValidate(widget, event)
      event = deep_copy(event)
      true # FIXME check for valid characters
      # FIXME check if not empty
    end

    # Get widgets specific for ppc
    # @return a map describing all ppc-specific widgets
    def Widgets
      if @_elilo_widgets == nil
        @_elilo_widgets = {
          "loader_location" => {
            "widget"        => :func,
            "widget_func"   => fun_ref(method(:getTargetWidget), "term ()"),
            "init"          => fun_ref(method(:targetInit), "void (string)"),
            "handle"        => fun_ref(
              method(:targetHandle),
              "symbol (string, map)"
            ),
            "store"         => fun_ref(
              method(:targetStore),
              "void (string, map)"
            ),
            "validate_type" => :function,
            "validate"      => fun_ref(
              method(:targetValidate),
              "boolean (string, map)"
            ),
            "help"          => " "
          }
        }
      end
      deep_copy(@_elilo_widgets)
    end
  end
end
