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
    def InstDetailsButtonHandle(widget, event)
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
    def LoaderOptionsButtonHandle(widget, event)
      event = deep_copy(event)
      lt = Bootloader.getLoaderType
      if lt == "none" || lt == "default"
        NoLoaderAvailable()
        return nil
      end
      :loader_details
    end

    # sections list widget


    # Refresh and redraw widget wits sections
    # @param [Array<Hash{String => Object>}] sects list of current sections
    def RedrawSectionsTable(sects)
      sects = deep_copy(sects)
      sec = Builtins.maplist(sects) do |s|
        info = ""
        type = _("Other")
        if Ops.get_string(s, "type", "") == "image"
          type = _("Image")
          image = Ops.get_string(s, "image", "")
          root = Ops.get(
            BootStorage.getHintedPartitionList([Ops.get_string(s, "root", "")]),
            0,
            ""
          )
          info = image != "" && image != nil ?
            Builtins.sformat(
              "%1   (%2%3)",
              image,
              Ops.get(BootCommon.splitPath(image), 0, ""),
              root == "" ?
                "" :
                Builtins.sformat(", root=%1", root)
            ) :
            ""
        elsif Ops.get_string(s, "type", "") == "xen"
          type = _("Xen")
          image = Ops.get_string(s, "image", "")
          root = Ops.get(
            BootStorage.getHintedPartitionList([Ops.get_string(s, "root", "")]),
            0,
            ""
          )
          info = image != "" && image != nil ?
            Builtins.sformat(
              "%1   (%2%3)",
              image,
              Ops.get(BootCommon.splitPath(image), 0, ""),
              root == "" ?
                "" :
                Builtins.sformat(", root=%1", root)
            ) :
            ""
        elsif Ops.get_string(s, "type", "") == "floppy"
          type = _("Floppy")
        elsif Ops.get_string(s, "type", "") == "menu"
          type = _("Menu")
          if Bootloader.getLoaderType == "grub"
            paths = Ops.get_string(s, "configfile", "")
            root = Ops.get_string(s, "root", "")
            info = Builtins.sformat("dev=%1 path=%2", root, paths)
          elsif Bootloader.getLoaderType == "zipl"
            info = Ops.get_string(s, "list", "")
          end
        elsif Ops.get_string(s, "type", "") == "dump"
          type = _("Dump")
          info = Ops.get_string(s, "dumpto", Ops.get_string(s, "dumptofs", ""))
        elsif Ops.get_string(s, "type", "") == "other"
          info = Ops.get_string(s, "chainloader", "")
        end
        Item(
          Id(Ops.get_string(s, "name", "")),
          Builtins.tolower(Ops.get(BootCommon.globals, "default", "")) ==
            Builtins.tolower(Ops.get_string(s, "name", "")) ?
            UI.Glyph(:CheckMark) :
            "",
          Ops.get_string(s, "name", ""),
          type,
          info
        )
      end
      UI.ChangeWidget(Id(:_tw_table), :Items, sec)

      nil
    end

    # Init function of widget
    # @param [String] widget string id of the widget
    def SectionsInit(widget)
      RedrawSectionsTable(BootCommon.sections)

      nil
    end


    def defaultHandle(key, event, index)
      event = deep_copy(event)
      current = Convert.to_string(UI.QueryWidget(Id(:_tw_table), :CurrentItem))
      Ops.set(BootCommon.globals, "default", current)
      RedrawSectionsTable(BootCommon.sections)
      UI.ChangeWidget(Id(:_tw_table), :CurrentItem, current)
      nil
    end

    def updownHandle(key, event, up, index)
      event = deep_copy(event)
      second = up ? Ops.subtract(index, 1) : Ops.add(index, 1)
      BootCommon.sections = Builtins::List.swap(
        BootCommon.sections,
        index,
        second
      )
      RedrawSectionsTable(BootCommon.sections)
      nil
    end

    def markSelected(index)
      selected = Ops.get(BootCommon.sections, index, {})
      name = Ops.get_string(selected, "name", "")
      BootCommon.current_section = deep_copy(selected)
      BootCommon.current_section_index = index
      BootCommon.current_section_name = name

      nil
    end

    def addHandle(key, event, index)
      event = deep_copy(event)
      markSelected(index)
      BootCommon.current_section_index = -1
      :add
    end

    def editHandle(key, event, index)
      event = deep_copy(event)
      markSelected(index)
      :edit
    end

    def deleteHandle(key, event, index)
      event = deep_copy(event)
      current = Convert.to_string(UI.QueryWidget(Id(:_tw_table), :CurrentItem))
      if confirmSectionDeletePopup(current)
        BootCommon.removed_sections = Builtins.add(
          BootCommon.removed_sections,
          Ops.get_string(BootCommon.sections, [index, "original_name"], "")
        )
        BootCommon.sections = Builtins.remove(BootCommon.sections, index)
        RedrawSectionsTable(BootCommon.sections)
        BootCommon.changed = true
      end

      nil
    end
    # Get map of widget
    # @return a map of widget
    def getSectionsWidget
      head = Header(
        # table header, Def stands for default
        _("Def."),
        # table header
        _("Label"),
        # table header
        _("Type"),
        # table header; header for section details, either
        # the specification of the kernel image to load,
        # or the specification of device to boot from
        _("Image / Device")
      )
      CWMTable.CreateTableDescr(
        {
          "add_delete_buttons" => true,
          "edit_button"        => true,
          "up_down_buttons"    => true,
          "custom_button"      => true,
          "custom_button_name" => _("Set as De&fault"),
          "custom_handle"      => fun_ref(
            method(:defaultHandle),
            "symbol (string, map, integer)"
          ),
          "header"             => head,
          "edit"               => fun_ref(
            method(:editHandle),
            "symbol (string, map, integer)"
          ),
          "delete"             => fun_ref(
            method(:deleteHandle),
            "symbol (string, map, integer)"
          ),
          "add"                => fun_ref(
            method(:addHandle),
            "symbol (string, map, integer)"
          ),
          "updown"             => fun_ref(
            method(:updownHandle),
            "symbol (string, map, boolean, integer)"
          )
        },
        {
          "init" => fun_ref(method(:SectionsInit), "void (string)"),
          "help" => SectionsHelp()
        }
      )
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
      if Ops.get(event, "ID") == key
        old_bl = Bootloader.getLoaderType
        new_bl = Convert.to_string(UI.QueryWidget(Id(key), :Value))

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
            Ops.set(BootCommon.other_bl, old_bl, Bootloader.Export)
            BootCommon.setLoaderType("none")
            BootCommon.location_changed = true
          end
          return :redraw
        end

        if new_bl == "grub2"
          Ops.set(BootCommon.other_bl, old_bl, Bootloader.Export)
          BootCommon.setLoaderType("grub2")
          Bootloader.Propose
          BootCommon.location_changed = true
          BootCommon.changed = true
          return :redraw
        end

        if new_bl == "grub2-efi"
          Ops.set(BootCommon.other_bl, old_bl, Bootloader.Export)
          BootCommon.setLoaderType("grub2-efi")
          Bootloader.Propose
          BootCommon.location_changed = true
          BootCommon.changed = true
          return :redraw
        end

        # warning - popup, followed by radio buttons
        label = _(
          "\n" +
            "You chose to change your boot loader. When converting \n" +
            "the configuration, some settings might be lost.\n" +
            "\n" +
            "The current configuration will be saved and you can\n" +
            "restore it if you return to the current boot loader.\n" +
            "\n" +
            "Select a course of action:\n"
        )

        contents = VBox(
          # warning label
          Label(label),
          VSpacing(1),
          RadioButtonGroup(
            Id(:action),
            VBox(
              Left(
                RadioButton(
                  Id(:propose),
                  # radiobutton
                  _("&Propose New Configuration")
                )
              ),
              Left(
                RadioButton(
                  Id(:convert),
                  # radiobutton
                  _("Co&nvert Current Configuration")
                )
              ),
              Stage.initial ?
                VSpacing(0) :
                Left(
                  RadioButton(
                    Id(:scratch),
                    # radiobutton
                    _("&Start New Configuration from Scratch")
                  )
                ),
              Mode.normal ?
                Left(
                  RadioButton(
                    Id(:read),
                    # radiobutton
                    _("&Read Configuration Saved on Disk")
                  )
                ) :
                VSpacing(0),
              Ops.get(BootCommon.other_bl, new_bl) == nil || Stage.initial ?
                VSpacing(0) :
                Left(
                  RadioButton(
                    Id(:prev),
                    # radiobutton
                    _("Res&tore Configuration Saved before Conversion")
                  )
                )
            )
          ),
          VSpacing(1),
          HBox(
            HStretch(),
            PushButton(Id(:ok), Opt(:key_F10), Label.OKButton),
            HSpacing(1),
            PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton),
            HStretch()
          )
        )
        UI.OpenDialog(contents)
        _def = :propose
        UI.ChangeWidget(Id(_def), :Value, true)
        ret = Convert.to_symbol(UI.UserInput)
        action = Convert.to_symbol(UI.QueryWidget(Id(:action), :CurrentButton))
        UI.CloseDialog
        if ret != :ok
          UI.ChangeWidget(Id("loader_type"), :Value, Bootloader.getLoaderType)
          return nil
        end

        if nil != action
          Builtins.y2milestone("Switching bootloader")
          if old_bl != "none"
            Ops.set(BootCommon.other_bl, old_bl, Bootloader.Export)
          end
          BootCommon.setLoaderType(new_bl)

          if action == :scratch
            Bootloader.Reset
          elsif action == :read
            progress_status = Progress.set(false)
            Bootloader.Read
            Progress.set(progress_status)
          elsif action == :propose
            Bootloader.Reset
            if Bootloader.getLoaderType == "grub"
              Yast.import "BootGRUB"
              BootGRUB.merge_level = :all
              Bootloader.Propose
              BootGRUB.merge_level = :main
            else
              Bootloader.Propose
            end
          elsif action == :prev
            Bootloader.Import(Ops.get_map(BootCommon.other_bl, new_bl, {}))
          elsif action == :convert
            #filter out uknown type of section
            BootCommon.sections = Builtins.filter(BootCommon.sections) do |sec|
              section_types = Bootloader.blsection_types
              if Builtins.contains(
                  section_types,
                  Ops.get_string(sec, "type", "")
                )
                next true
              else
                next false
              end
            end
          end
        end
        BootCommon.location_changed = true
        BootCommon.changed = true
        return :redraw
      end
      nil
    end

    # Validate function of a widget
    # @param [String] widget string widget key
    # @param [Hash] event map event that caused validation
    # @return [Boolean] true if validation succeeded
    def LoaderTypeValidate(widget, event)
      event = deep_copy(event)
      if Ops.get(event, "ID") == "sections" &&
          BootCommon.getLoaderType(false) == "none"
        # popup message
        Popup.Message(_("Select the boot loader before editing sections."))
        return false
      end
      true
    end


    # Store function of a widget
    # @param [String] widget string widget key
    # @param [Hash] event map event that caused the operation
    def LoaderTypeStore(widget, event)
      event = deep_copy(event)
      ret = false
      if Ops.get(BootCommon.globals, "trusted_grub", "") == "true"
        if !Package.Installed("trustedgrub") && Mode.normal
          if !PackageSystem.CheckAndInstallPackages(["trustedgrub"])
            if !Mode.commandline
              Popup.Error(Message.CannotContinueWithoutPackagesInstalled)
            end
            Builtins.y2error(
              "Installation of package trustedgrub failed or aborted"
            )
          end
        end
      end

      nil
    end

    # manual edit button

    # Handle function of a widget
    # @param [String] key any widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] to return to wizard sequencer, or nil
    def manualEditHandle(key, event)
      event = deep_copy(event)
      :manual
    end

    # Get map of widget
    # @return a map of widget
    def getManualEditWidget
      #	    "help" : getManualEditHelp (),
      {
        "widget"        => :custom,
        "custom_widget" => HBox(
          HStretch(),
          # pushbutton
          PushButton(Id(:manual), _("E&dit Configuration Files")),
          HStretch()
        ),
        "handle_events" => [:manual],
        "handle"        => fun_ref(
          method(:manualEditHandle),
          "symbol (string, map)"
        )
      }
    end

    # reset menu button


    # Init function of widget
    # @param [String] widget any id of the widget
    def resetButtonInit(widget)
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
    def resetButtonHandle(widget, event)
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
      elsif op == :propose_deep
        Yast.import "BootGRUB"
        BootGRUB.merge_level = :all
        Bootloader.Propose
        BootGRUB.merge_level = :main
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

    # Get the main dialog tabs description
    # @return a map the description of the tabs
    def TabsDescr
      lt = Bootloader.getLoaderType
      {
        "sections"     => {
          # tab header
          "header"       => _("&Section Management"),
          "contents"     => HBox(
            HSpacing(3),
            VBox(VSpacing(1), "sections", VSpacing(1)),
            HSpacing(3)
          ),
          "widget_names" => ["DisBackButton", "sections"]
        },
        "installation" => {
          # tab header
          "header"       => _("Boot Loader &Installation"),
          "contents"     => HBox(
            HStretch(),
            VBox(
              VStretch(),
              Frame(
                _("Type"),
                VBox(
                  VSpacing(0.4),
                  HBox(
                    HSpacing(2),
                    "loader_type",
                    HStretch(),
                    VBox(
                      Label(""),
                      lt == "none" || lt == "default" || lt == "zipl" ?
                        Empty() :
                        "loader_options"
                    ),
                    HSpacing(2)
                  ),
                  VSpacing(0.4)
                )
              ),
              VStretch(),
              lt == "none" || lt == "default" || lt == "zipl" ?
                Empty() :
                "loader_location",
              VStretch(),
              lt != "grub" && lt != "grub2" ? Empty() : "inst_details",
              VStretch()
            ),
            HStretch()
          ),
          "widget_names" => lt == "none" || lt == "default" || lt == "zipl" ?
            ["loader_type", "loader_options"] :
            ["loader_type", "loader_options", "loader_location", "inst_details"]
        }
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
        "sections"       => getSectionsWidget,
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
          "help"              => LoaderTypeHelp(),
          "store"             => fun_ref(
            method(:LoaderTypeStore),
            "void (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:LoaderTypeValidate),
            "boolean (string, map)"
          )
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
