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
  module BootloaderRoutinesSectionWidgetsInclude
    def initialize_bootloader_routines_section_widgets(include_target)
      textdomain "bootloader"

      Yast.import "CWM"
      Yast.import "Initrd"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "Bootloader"
      Yast.import "BootStorage"
      Yast.import "Popup"
      Yast.import "FileUtils"


      Yast.include include_target, "bootloader/routines/helps.rb"
      Yast.include include_target, "bootloader/routines/section_helps.rb"

      @validation_map = {
        "image"  => fun_ref(method(:validate_image), "boolean (string, map)"),
        "initrd" => fun_ref(method(:validate_initrd), "boolean (string, map)")
      }

      # Map of fallback handlers for events on sections
      @section_handlers = {
        "init"  => fun_ref(method(:SectionOptionInit), "void (string)"),
        "store" => fun_ref(method(:SectionOptionStore), "void (string, map)")
      }



      # Cache for CommonSectionWidgets
      @_common_section_widgets = nil
    end

    def validate_image(widget, event)
      event = deep_copy(event)
      value = Convert.to_string(UI.QueryWidget(Id(widget), :Value))
      if value == ""
        Popup.Error(_("Image section must have specified kernel image"))
        UI.SetFocus(Id(widget))
        return false
      end
      if !Mode.installation && !Mode.repair
        if !FileUtils.Exists(value)
          if !Popup.YesNo(
              _("Image file doesn't exist now. Do you really want use it?")
            )
            UI.SetFocus(Id(widget))
            return false
          end
        end
      end

      true
    end

    def validate_initrd(widget, event)
      event = deep_copy(event)
      value = Convert.to_string(UI.QueryWidget(Id(widget), :Value))
      if !Mode.installation && !Mode.repair
        if !FileUtils.Exists(value)
          if !Popup.YesNo(
              _("Initrd file doesn't exist now. Do you really want use it?")
            )
            UI.SetFocus(Id(widget))
            return false
          end
        end
      end
      true
    end

    # Init function for widget value
    # @param [String] widget any id of the widget
    def SectionOptionInit(widget)
      UI.ChangeWidget(
        Id(widget),
        :Value,
        Ops.get_string(BootCommon.current_section, widget, "")
      )

      nil
    end

    # Store function of a widget
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    def SectionOptionStore(widget, event)
      event = deep_copy(event)
      Ops.set(
        BootCommon.current_section,
        widget,
        UI.QueryWidget(Id(widget), :Value)
      )

      nil
    end


    def InitSectionBool(widget)
      value = Ops.get_string(BootCommon.current_section, widget, "false") == "true"
      UI.ChangeWidget(Id(widget), :Value, value)

      nil
    end

    def StoreSectionBool(widget, event)
      event = deep_copy(event)
      value = Convert.to_boolean(UI.QueryWidget(Id(widget), :Value))
      Ops.set(BootCommon.current_section, widget, value ? "true" : "false")

      nil
    end

    def SectionCheckBoxWidget(name)
      {
        "label"  => Ops.get(@section_descriptions, name, name),
        "widget" => :checkbox,
        "help"   => Ops.get(@section_help_messages, name, ""),
        "init"   => fun_ref(method(:InitSectionBool), "void (string)"),
        "store"  => fun_ref(method(:StoreSectionBool), "void (string, map)")
      }
    end


    def InitEnableSelinux(widget)
      append = Ops.get_string(BootCommon.current_section, "append", "")
      if append != "" &&
          Ops.get_string(BootCommon.current_section, "type", "") == "image"
        if Builtins.search(append, "security=selinux") != nil &&
            Builtins.search(append, "selinux=1") != nil &&
            Builtins.search(append, "enforcing=0") != nil
          UI.ChangeWidget(Id(widget), :Value, true)
        else
          UI.ChangeWidget(Id(widget), :Value, false)
        end
      else
        UI.ChangeWidget(Id(widget), :Value, false)
      end

      if Ops.get_string(BootCommon.current_section, "type", "") != "image" ||
          Ops.get_string(BootCommon.current_section, "original_name", "") == "failsafe"
        UI.ChangeWidget(Id(widget), :Enabled, false)
      end

      nil
    end

    def add_selinux_append(append)
      ret = append
      if Builtins.search(append, "security=selinux") == nil
        ret = Ops.add(ret, " security=selinux")
      end
      if Builtins.search(append, "selinux=1") == nil
        ret = Ops.add(ret, " selinux=1")
      end
      if Builtins.search(append, "enforcing=0") == nil
        ret = Ops.add(ret, " enforcing=0")
      end
      ret
    end

    def delete_selinux_append(append)
      ret = append
      l_append = Builtins.splitstring(append, " ")
      l_append = Builtins.filter(l_append) do |v|
        if v != "" && Builtins.tolower(v) != "security=selinux" &&
            Builtins.tolower(v) != "selinux=1" &&
            Builtins.tolower(v) != "enforcing=0"
          next true
        end
      end
      ret = Builtins.mergestring(l_append, " ")
      ret
    end

    def StoreEnableSelinux(widget, event)
      event = deep_copy(event)
      #    string append = BootCommon::current_section["append"]:"";
      append = Convert.to_string(UI.QueryWidget(Id("append"), :Value))
      value = Convert.to_boolean(UI.QueryWidget(Id(widget), :Value))
      if value
        append = add_selinux_append(append)
        BootCommon.enable_selinux = true
      else
        append = delete_selinux_append(append)
        BootCommon.enable_selinux = false
      end
      Ops.set(BootCommon.current_section, "append", append)

      nil
    end

    def HandleEnableSelinux(widget, event)
      event = deep_copy(event)
      value = Convert.to_boolean(UI.QueryWidget(Id(widget), :Value))
      #string append = BootCommon::current_section["append"]:"";
      append = Convert.to_string(UI.QueryWidget(Id("append"), :Value))
      if value
        UI.ChangeWidget(Id("append"), :Value, add_selinux_append(append))
      else
        UI.ChangeWidget(Id("append"), :Value, delete_selinux_append(append))
      end
      nil
    end
    def EnableSelinux
      {
        "label"  => _("Enable &SELinux"),
        "widget" => :checkbox,
        "help"   => Ops.get(@section_help_messages, "enable_selinux", ""),
        "init"   => fun_ref(method(:InitEnableSelinux), "void (string)"),
        "handle" => fun_ref(
          method(:HandleEnableSelinux),
          "symbol (string, map)"
        ),
        "opt"    => [:notify],
        "store"  => fun_ref(method(:StoreEnableSelinux), "void (string, map)")
      }
    end


    def SectionTextFieldWidget(name)
      ret = {
        "label"  => Ops.get(@section_descriptions, name, name),
        "widget" => :textentry,
        "help"   => Ops.get(@section_help_messages, name, "")
      }

      if Builtins.haskey(@validation_map, name)
        Ops.set(ret, "validate_type", :function)
        Ops.set(ret, "validate_function", Ops.get(@validation_map, name)) #nil cannot happen
      end

      deep_copy(ret)
    end

    # Handle function of a widget (InputField + browse button)
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] nil
    def HandleSectionBrowse(widget, event)
      event = deep_copy(event)
      current = Convert.to_string(UI.QueryWidget(Id(widget), :Value))
      current = "/boot" if current == "" || current == nil
      # file open popup caption
      current = UI.AskForExistingFile(current, "*", _("Select File"))
      UI.ChangeWidget(Id(widget), :Value, current) if current != nil
      nil
    end

    # Handle function of a widget (InputField + browse button)
    # Asks for directory instead file
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] nil
    def HandleSectionBrowseDirectory(widget, event)
      event = deep_copy(event)
      current = Convert.to_string(UI.QueryWidget(Id(widget), :Value))
      # file open popup caption
      current = UI.AskForExistingFile(current, "*", _("Select File"))
      UI.ChangeWidget(Id(widget), :Value, current) if current != nil
      nil
    end

    # Generic widget of a inputfield + browse button
    # Use validation function from  validation_map
    # if it is necessary create own definition of widget
    # @param string lable of widget
    # @param string help text for widget
    # @param [String] id of widget
    # @return [Hash{String => Object}] CWS widget
    def SectionInputFieldBrowseWidget(id)
      browse = Ops.add("browse", id)
      ret = {
        "widget"        => :custom,
        "custom_widget" => HBox(
          Left(
            InputField(
              Id(id),
              Opt(:hstretch),
              Ops.get(@section_descriptions, id, id)
            )
          ),
          VBox(
            Label(""),
            PushButton(Id(browse), Opt(:notify), Label.BrowseButton)
          )
        ),
        "init"          => fun_ref(method(:SectionOptionInit), "void (string)"),
        "store"         => fun_ref(
          method(:SectionOptionStore),
          "void (string, map)"
        ),
        "handle"        => fun_ref(
          method(:HandleSectionBrowse),
          "symbol (string, map)"
        ),
        "handle_events" => [browse],
        "help"          => Ops.get(@section_help_messages, id, id)
      }
      if Builtins.haskey(@validation_map, id)
        Ops.set(ret, "validate_type", :function)
        Ops.set(ret, "validate_function", Ops.get(@validation_map, id)) #nil cannot happen
      end

      deep_copy(ret)
    end

    def SectionInputFieldBrowseDirectoryWidget(id)
      ret = SectionInputFieldBrowseWidget(id)
      Ops.set(
        ret,
        "handle",
        fun_ref(method(:HandleSectionBrowseDirectory), "symbol (string, map)")
      )
      deep_copy(ret)
    end


    def InitSectionInt(widget)
      value = Builtins.tointeger(
        Ops.get_string(BootCommon.current_section, widget, "0")
      )
      UI.ChangeWidget(Id(widget), :Value, value)

      nil
    end

    def StoreSectionInt(widget, event)
      event = deep_copy(event)
      value = Convert.to_integer(UI.QueryWidget(Id(widget), :Value))
      Ops.set(BootCommon.current_section, widget, Builtins.tostring(value))

      nil
    end


    def SectionIntFieldWidget(name, min, max)
      ret = {
        "label"  => Ops.get(@section_descriptions, name, name),
        "widget" => :intfield,
        "help"   => Ops.get(@section_help_messages, name, name),
        "init"   => fun_ref(method(:InitSectionInt), "void (string)"),
        "store"  => fun_ref(method(:StoreSectionInt), "void (string, map)")
      }
      Ops.set(ret, "minimum", min) if min != nil
      Ops.set(ret, "maximum", max) if max != nil

      deep_copy(ret)
    end
    # Validate function of the name widget
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    # @return [Boolean] true if widget settings ok
    def SectionNameValidate(widget, event)
      event = deep_copy(event)
      bl = Bootloader.getLoaderType

      existing = []
      Builtins.foreach(BootCommon.sections) do |s|
        existing = Builtins.add(existing, Ops.get_string(s, "name", ""))
      end
      existing = Builtins.filter(existing) do |l|
        l != BootCommon.current_section_name
      end
      existing = Builtins.add(existing, "")
      new = Convert.to_string(UI.QueryWidget(Id(widget), :Value))

      if Builtins.contains(existing, new)
        usedNameErrorPopup
        return false
      end

      # bnc#456362 filter out special chars like diacritics china chars etc.
      if Mode.normal && bl == "grub"
        filtered_new = Builtins.filterchars(
          new,
          "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 /\\_.-()"
        )

        if filtered_new != new
          Report.Error(_("The name includes unallowable char(s)"))
          return false
        end
      end
      true
    end

    # Store function of the name widget
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    def SectionNameStore(widget, event)
      event = deep_copy(event)
      value = Convert.to_string(UI.QueryWidget(Id(widget), :Value))

      #check if we need change default value in globals
      if Ops.get(BootCommon.globals, "default") ==
          Ops.get_string(BootCommon.current_section, widget, "")
        Ops.set(BootCommon.globals, "default", value)
      end

      Ops.set(BootCommon.current_section, widget, value)

      nil
    end


    # Init function of the root device widget
    # @param [String] widget any id of the widget
    def RootDeviceInit(widget)
      Builtins.y2milestone("RootDeviceInit: %1", widget)
      available = BootStorage.getPartitionList(:root, Bootloader.getLoaderType)
      # if we mount any of these devices by id, label etc., we add a hint to
      # that effect to the item
      Builtins.y2milestone(
        "RootDeviceInit: getHintedPartitionList for %1",
        available
      )
      available = BootStorage.getHintedPartitionList(available)
      UI.ChangeWidget(Id(widget), :Items, available)
      UI.ChangeWidget(
        Id(widget),
        :Value,
        Ops.get(
          BootStorage.getHintedPartitionList(
            [Ops.get_string(BootCommon.current_section, widget, "")]
          ),
          0,
          ""
        )
      )

      nil
    end

    # Store function of the root device widget
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    def RootDeviceStore(widget, event)
      event = deep_copy(event)
      Ops.set(
        BootCommon.current_section,
        widget,
        Ops.get(
          Builtins.splitstring(
            Convert.to_string(UI.QueryWidget(Id(widget), :Value)),
            " "
          ),
          0,
          ""
        )
      )

      nil
    end

    # Handle function of the root device widget
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] to return to wizard sequencer, or nil
    def RootDeviceHandle(widget, event)
      event = deep_copy(event)
      return nil if Ops.get(event, "EventReason") != "ValueChanged"

      # append hint string when user changed root device
      current = Ops.get(
        Builtins.splitstring(
          Convert.to_string(UI.QueryWidget(Id(widget), :Value)),
          " "
        ),
        0,
        ""
      )
      # check against the list of existing partitions
      available = BootStorage.getPartitionList(:root, Bootloader.getLoaderType)
      if Builtins.contains(available, current)
        UI.ChangeWidget(
          Id(widget),
          :Value,
          Ops.get(BootStorage.getHintedPartitionList([current]), 0, "")
        )
      end
      nil
    end

    # Init function of widget
    # @param [String] widget any id of the widget
    def VgaModeInit(widget)
      vga_modes = Initrd.VgaModes
      items = Builtins.maplist(vga_modes) do |m|
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
        Item(Id("ask"), _("Ask for resolution during boot."))
      )
      items = Builtins.prepend(
        items,
        Item(Id("extended"), _("Standard 8-pixel font mode."))
      )
      # item of a combo box
      items = Builtins.prepend(items, Item(Id("normal"), _("Text Mode")))
      items = Builtins.prepend(items, Item(Id(""), _("Unspecified")))
      UI.ChangeWidget(Id(widget), :Items, items)
      SectionOptionInit(widget)

      nil
    end

    # Init function of widget
    # @param [String] widget any id of the widget
    def ChainloaderInit(widget)
      available = BootStorage.getPartitionList(
        :boot_other,
        Bootloader.getLoaderType
      )
      UI.ChangeWidget(Id(widget), :Items, available)
      SectionOptionInit(widget)

      nil
    end

    # Widget for selecting section type
    # @return [Yast::Term] widget
    def SectionTypesWidget
      count = 0
      contents = VBox()
      if BootCommon.current_section_name != ""
        contents = Builtins.add(
          contents,
          Left(
            RadioButton(
              Id("clone"),
              # radio button
              _("Clone Selected Section"),
              true
            )
          )
        )
        count = Ops.add(count, 1)
      end
      section_types = Bootloader.blsection_types
      section_types_descr = {
        # radio button
        "image" => _("Image Section"),
        # radio button
        "xen"   => _("Xen Section"),
        # radio button (don't translate 'chainloader')
        "other" => _(
          "Other System (Chainloader)"
        ),
        # radio button
        "menu"  => _("Menu Section"),
        # radio button
        "dump"  => _("Dump Section")
      }
      Builtins.foreach(section_types) do |t|
        if Ops.greater_than(count, 0)
          contents = Builtins.add(contents, VSpacing(0.4))
        end
        count = Ops.add(count, 1)
        contents = Builtins.add(
          contents,
          Left(
            RadioButton(Id(t), Ops.get(section_types_descr, t, t), count == 1)
          )
        )
      end
      # frame
      contents = Frame(
        _("Section Type"),
        VBox(
          VSpacing(1),
          HBox(
            HSpacing(2),
            RadioButtonGroup(Id(:sect_type), contents),
            HSpacing(2)
          ),
          VSpacing(1)
        )
      )
      deep_copy(contents)
    end

    # Handle function of a widget
    # @param [String] widget string widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] to return to wizard sequencer, or nil
    def SectionTypeHandle(widget, event)
      event = deep_copy(event)
      return nil if Ops.get(event, "ID") != :next
      selected = Convert.to_string(
        UI.QueryWidget(Id(:sect_type), :CurrentButton)
      )
      original_name = selected
      original_name = "linux" if original_name == "image"
      if selected != "clone"
        BootCommon.current_section = {
          "type"          => selected,
          "original_name" => original_name
        }
      else
        Ops.set(BootCommon.current_section, "name", "")
        # fix the problem with missing YaST commnet in menu.lst
        # it seems be correct if original_name stay same...
        Ops.set(BootCommon.current_section, "original_name", "")
        Ops.set(BootCommon.current_section, "__auto", false)
        # fix for problem with cloning section
        if Builtins.haskey(BootCommon.current_section, "lines_cache_id")
          BootCommon.current_section = Builtins.remove(
            BootCommon.current_section,
            "lines_cache_id"
          )
        end
      end
      Builtins.y2milestone(
        "Added section template: %1",
        BootCommon.current_section
      )
      nil
    end

    # Get common widgets for loader sections
    # @return a map describing common loader section related widgets
    def CommonSectionWidgets
      if @_common_section_widgets == nil
        @_common_section_widgets = {
          "name"           => {
            # text entry
            "label"             => _("Section &Name"),
            "widget"            => :textentry,
            "validate_type"     => :function,
            "validate_function" => fun_ref(
              method(:SectionNameValidate),
              "boolean (string, map)"
            ),
            "store"             => fun_ref(
              method(:SectionNameStore),
              "void (string, map)"
            ),
            "help"              => SectionNameHelp()
          },
          "image"          => SectionInputFieldBrowseWidget("image"),
          "initrd"         => SectionInputFieldBrowseWidget("initrd"),
          "xen"            => SectionInputFieldBrowseWidget("xen"),
          "target"         => SectionInputFieldBrowseDirectoryWidget("target"),
          "parmfile"       => SectionInputFieldBrowseWidget("parmfile"),
          "dumpto"         => {
            #FIXME when exist browse device use it
            "label"  => Ops.get(
              @section_descriptions,
              "dumpto",
              "dumpto"
            ),
            "widget" => :textentry,
            "help"   => Ops.get(@section_help_messages, "dumpto", "")
          },
          "dumptofs"       => {
            #FIXME when exist browse device use it
            "label"  => Ops.get(
              @section_descriptions,
              "dumptofs",
              "dumptofs"
            ),
            "widget" => :textentry,
            "help"   => Ops.get(@section_help_messages, "dumptofs", "")
          },
          "root"           => {
            "widget" => :combobox,
            # combo box
            "label"  => Ops.get(
              @section_descriptions,
              "root",
              "root"
            ),
            "opt"    => [:editable, :hstretch, :notify],
            "init"   => fun_ref(method(:RootDeviceInit), "void (string)"),
            "handle" => fun_ref(
              method(:RootDeviceHandle),
              "symbol (string, map)"
            ),
            "store"  => fun_ref(method(:RootDeviceStore), "void (string, map)"),
            "help"   => Ops.get(@section_help_messages, "root", "")
          },
          "vgamode"        => {
            "widget" => :combobox,
            # combo box
            "label"  => Ops.get(
              @section_descriptions,
              "vgamode",
              "vgamode"
            ),
            "opt"    => [:editable, :hstretch],
            "init"   => fun_ref(method(:VgaModeInit), "void (string)"),
            "help"   => Ops.get(@section_help_messages, "vgamode", "")
          },
          "append"         => SectionTextFieldWidget("append"),
          "xen_append"     => SectionTextFieldWidget("xen_append"),
          "configfile"     => SectionTextFieldWidget("configfile"),
          "list"           => SectionTextFieldWidget("list"),
          "chainloader"    => {
            "widget" => :combobox,
            "init"   => fun_ref(method(:ChainloaderInit), "void (string)"),
            "help"   => Ops.get(@section_help_messages, "chainloader", ""),
            "label"  => Ops.get(
              @section_descriptions,
              "chainloader",
              "chainloader"
            ),
            "opt"    => [:editable, :hstretch]
          },
          "section_type"   => {
            "widget"      => :func,
            "widget_func" => fun_ref(method(:SectionTypesWidget), "term ()"),
            "handle"      => fun_ref(
              method(:SectionTypeHandle),
              "symbol (string, map)"
            ),
            "help"        => SectionTypeHelp()
          },
          "makeactive"     => SectionCheckBoxWidget("makeactive"),
          "noverifyroot"   => SectionCheckBoxWidget("noverifyroot"),
          "remap"          => SectionCheckBoxWidget("remap"),
          "relocatable"    => SectionCheckBoxWidget("relocatable"),
          "enable_selinux" => EnableSelinux(),
          "prompt"         => SectionCheckBoxWidget("prompt"),
          "blockoffset"    => SectionIntFieldWidget("blockoffset", 0, nil),
          "default"        => SectionIntFieldWidget("default", 1, 10),
          "timeout"        => SectionIntFieldWidget("timeout", 0, 60),
          "optional"       => SectionCheckBoxWidget("optional"),
          "copy"           => SectionCheckBoxWidget("copy"),
          "other" =>
            #FIXME change to combobox and add proper init function
            SectionTextFieldWidget("other")
        }
      end

      deep_copy(@_common_section_widgets)
    end
  end
end
