# encoding: utf-8

# File:
#      bootloader.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Main file of bootloader configuration
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  module BootloaderRoutinesGlobalWidgetsInclude
    def initialize_bootloader_routines_global_widgets(include_target)
      textdomain "bootloader"

      Yast.import "CWM"
      Yast.import "CWMTab"
      Yast.import "CWMTable"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "Bootloader"
      Yast.import "Progress"
      Yast.import "PackageSystem"
      Yast.import "Package"
      Yast.import "Message"



      Yast.include include_target, "bootloader/routines/helps.rb"

      # Map of default (fallback) handlers for widget events on global widgets
      @global_handlers = {
        "init"  => fun_ref(method(:GlobalOptionInit), "void (string)"),
        "store" => fun_ref(method(:GlobalOptionStore), "void (string, map)")
      }

      # Cache for CommonGlobalWidgets function
      @_common_global_widgets = nil
    end

    # Init function of widget
    # @param [String] widget string id of the widget
    def GlobalOptionInit(widget)
      return if widget == "adv_button"
      UI.ChangeWidget(
        Id(widget),
        :Value,
        Ops.get(BootCommon.globals, widget, "")
      )

      nil
    end

    # Store function of a widget
    # @param [String] widget string widget key
    # @param [Hash] event map event that caused the operation
    def GlobalOptionStore(widget, event)
      event = deep_copy(event)
      return if widget == "adv_button"
      Ops.set(
        BootCommon.globals,
        widget,
        Convert.to_string(UI.QueryWidget(Id(widget), :Value))
      )

      nil
    end

    # Handle function of a widget
    # @param [String] widget string widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] to return to wizard sequencer, or nil
    def InstDetailsButtonHandle(_widget, event)
      event = deep_copy(event)
      lt = Bootloader.getLoaderType
      if lt == "none" || lt == "default"
        NoLoaderAvailable()
        return nil
      end
      :inst_details
    end

    # Handle function of a widget
    # @param [String] widget string widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] to return to wizard sequencer, or nil
    def LoaderOptionsButtonHandle(_widget, event)
      event = deep_copy(event)
      lt = Bootloader.getLoaderType
      if lt == "none" || lt == "default"
        NoLoaderAvailable()
        return nil
      end
      :loader_details
    end

    # loader type widget

    # Get the widget for boot laoder selection combo
    # @return [Yast::Term] the widget
    def LoaderTypeComboWidget
      ComboBox(
        Id("loader_type"),
        Opt(:notify),
        # combo box
        _("&Boot Loader"),
        Builtins.maplist(BootCommon.getBootloaders) do |l|
          Item(Id(l), BootCommon.getLoaderName(l, :combo))
        end
      )
    end

    # Init function of widget
    # @param [String] widget string id of the widget
    def LoaderTypeComboInit(widget)
      UI.ChangeWidget(Id(widget), :Value, Bootloader.getLoaderType)

      nil
    end

    # Handle function of a widget
    # @param [String] key any widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] to return to wizard sequencer, or nil
    def LoaderTypeComboHandle(key, event)
      event = deep_copy(event)
      return if event["ID"] != key # FIXME can it happen at all?
      old_bl = Bootloader.getLoaderType
      new_bl = UI.QueryWidget(Id(key), :Value).to_s

      return nil if old_bl == new_bl

      if new_bl == "none"
        # popup - Continue/Cancel
        if Popup.ContinueCancel(
            _(
              "\n" +
                "If you do not install any boot loader, the system\n" +
                "might not start.\n" +
                "\n" +
                "Proceed?\n"
            )
          )
          BootCommon.setLoaderType("none")
          BootCommon.location_changed = true
        end
        return :redraw
      end

      if ["grub2", "grub2-efi"].include?(new_bl)
        BootCommon.setLoaderType(new_bl)
        Bootloader.Propose
        BootCommon.location_changed = true
        BootCommon.changed = true
        return :redraw
      end

      raise "Unexpected value of loader type '#{new_bl}'"
    end

    # reset menu button


    # Init function of widget
    # @param [String] widget any id of the widget
    def resetButtonInit(_widget)
      items = []
      items = Builtins.add(
        items,
        Item(
          Id(:manual),
          # menu button entry
          _("E&dit Configuration Files")
        )
      )
      if BootCommon.getBooleanAttrib("propose")
        items = Builtins.add(
          items,
          # menubutton item, keep as short as possible
          Item(Id(:propose), _("&Propose New Configuration"))
        )
      end
      if BootCommon.getBooleanAttrib("scratch")
        items = Builtins.add(
          items,
          # menubutton item, keep as short as possible
          Item(Id(:scratch), _("&Start from Scratch"))
        )
      end
      if (Mode.normal || Mode.config || Mode.repair) &&
          BootCommon.getBooleanAttrib("read")
        items = Builtins.add(
          items,
          # menubutton item, keep as short as possible
          Item(Id(:reread), _("&Reread Configuration from Disk"))
        )
      end
      additional_entries = Convert.to_list(
        BootCommon.getAnyTypeAttrib("additional_entries", [])
      )
      items = Builtins.merge(items, additional_entries)

      if (Mode.normal || Mode.repair) &&
          BootCommon.getBooleanAttrib("restore_mbr") &&
          Ops.greater_than(
            SCR.Read(path(".target.size"), "/boot/backup_mbr"),
            0
          )
        items = Builtins.add(
          items,
          # menubutton item, keep as short as possible
          Item(Id(:restore_mbr), _("Restore MBR of Hard Disk"))
        )
      end

      if Mode.normal || Mode.repair
        items = Builtins.add(
          items,
          # menubutton item, keep as short as possible
          Item(Id(:init), _("Write bootloader boot code to disk"))
        )
      end

      if Ops.greater_than(Builtins.size(items), 0)
        UI.ReplaceWidget(
          Id(:adv_rp),
          # menu button
          MenuButton(Id(:reset), _("Other"), items)
        )
      else
        UI.ReplaceWidget(Id(:adv_rp), VSpacing(0))
      end

      nil
    end

    # Handle function of a widget
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] to return to wizard sequencer, or nil
    def resetButtonHandle(_widget, event)
      event = deep_copy(event)
      op = Ops.get(event, "ID")
      return :manual if op == :manual
      if op == :restore_mbr
        doit = restoreMBRPopup(BootCommon.mbrDisk)
        Builtins.y2milestone("Rewrite MBR with saved one: %1", doit)
        if doit
          ret = BootCommon.restoreMBR(BootCommon.mbrDisk)
          if ret
            # message popup
            Popup.Message(_("MBR restored successfully."))
          else
            # message popup
            Popup.Message(_("Failed to restore MBR."))
          end
        end
        return nil
      end

      if !(Ops.is_symbol?(op) &&
          Builtins.contains(
            [:scratch, :reread, :propose_deep, :propose],
            Convert.to_symbol(op)
          ))
        return nil
      end
      Bootloader.Reset
      if op == :scratch
        Builtins.y2debug("Not reading anything for starting from scratch")
      elsif op == :reread
        Bootloader.Read
      elsif op == :init
        # Bootloader::blSave (false, false, false);
        ret = BootCommon.InitializeBootloader
        ret = false if ret == nil

        Popup.Warning(_("Writing bootloader settings failed.")) if !ret
      elsif op == :propose
        Bootloader.Propose
      end

      :redraw
    end





    # Get map of widget
    # @return a map of widget
    def getAdvancedButtonWidget
      {
        "widget"        => :custom,
        "custom_widget" => ReplacePoint(Id(:adv_rp), VBox()),
        "handle"        => fun_ref(
          method(:resetButtonHandle),
          "symbol (string, map)"
        ),
        "init"          => fun_ref(method(:resetButtonInit), "void (string)"),
        "help"          => getAdvancedButtonHelp
      }
    end

    # Get general widgets for global bootloader options
    # @return a map describing all general widgets for global options
    def CommonGlobalWidgets
      if @_common_global_widgets != nil
        return deep_copy(@_common_global_widgets)
      end
      @_common_global_widgets = {
        "adv_button"     => getAdvancedButtonWidget,
        "loader_type"    => {
          "widget"            => :func,
          "widget_func"       => fun_ref(
            method(:LoaderTypeComboWidget),
            "term ()"
          ),
          "init"              => fun_ref(
            method(:LoaderTypeComboInit),
            "void (string)"
          ),
          "handle"            => fun_ref(
            method(:LoaderTypeComboHandle),
            "symbol (string, map)"
          ),
          "help"              => LoaderTypeHelp()
        },
        "loader_options" => {
          "widget"        => :push_button,
          # push button
          "label"         => _("Boot &Loader Options"),
          "handle_events" => ["loader_options"],
          "handle"        => fun_ref(
            method(:LoaderOptionsButtonHandle),
            "symbol (string, map)"
          ),
          "help"          => LoaderOptionsHelp()
        },
        #FIXME: after deleting all using of metadata delete widget from
        # from CommonGlobalWidgets the button is only for GRUB...
        "inst_details"   => {
          "widget"        => :push_button,
          # push button
          "label"         => _(
            "Boot Loader Installation &Details"
          ),
          "handle_events" => ["inst_details"],
          "handle"        => fun_ref(
            method(:InstDetailsButtonHandle),
            "symbol (string, map)"
          ),
          "help"          => InstDetailsHelp()
        }
      }



      deep_copy(@_common_global_widgets)
    end
  end
end
