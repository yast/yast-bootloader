# encoding: utf-8

# File:
#      modules/BootGRUB.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for GRUB configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id$
#
module Yast
  module BootloaderGrubOptionsInclude
    def initialize_bootloader_grub_options(include_target)
      textdomain "bootloader"

      Yast.import "Label"
      Yast.import "BootStorage"

      Yast.include include_target, "bootloader/routines/common_options.rb"
      Yast.include include_target, "bootloader/routines/popups.rb"
      Yast.include include_target, "bootloader/routines/helps.rb"
      Yast.include include_target, "bootloader/grub/helps.rb"
    end

    # Handle function of a widget
    # @param [String] widget string id of the widget
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] always nil
    def HandlePasswdWidget(widget, event)
      event = deep_copy(event)
      if Ops.get(event, "ID") == :use_pas
        enabled = Convert.to_boolean(UI.QueryWidget(Id(:use_pas), :Value))
        UI.ChangeWidget(Id(:pw1), :Enabled, enabled)
        UI.ChangeWidget(Id(:pw2), :Enabled, enabled)
      end
      nil
    end

    # Validate function of a popup
    # @param [String] key any widget key
    # @param [Hash] event map event that caused validation
    # @return [Boolean] true if widget settings ok
    def ValidatePasswdWidget(key, event)
      event = deep_copy(event)
      return true if !Convert.to_boolean(UI.QueryWidget(Id(:use_pas), :Value))
      if UI.QueryWidget(Id(:pw1), :Value) == ""
        emptyPasswdErrorPopup
        UI.SetFocus(Id(:pw1))
        return false
      end
      if UI.QueryWidget(Id(:pw1), :Value) == UI.QueryWidget(Id(:pw2), :Value)
        return true
      end
      passwdMissmatchPopup
      UI.SetFocus(Id(:pw1))
      false
    end

    def passwd_content
      HBox(
        CheckBoxFrame(
          Id(:use_pas),
          _("Prot&ect Boot Loader with Password"),
          true,
          HBox(
            HSpacing(2),
            # text entry
            Password(Id(:pw1), Opt(:hstretch), _("&Password")),
            # text entry
            HSpacing(2),
            Password(Id(:pw2), Opt(:hstretch), _("Re&type Password")),
            HStretch()
          )
        )
      )
    end


    def InitDiskOrder(widget)
      disksOrder = BootStorage.DisksOrder

      UI.ChangeWidget(Id(:disks), :Items, disksOrder)
      UI.ChangeWidget(Id(:disks), :CurrentItem, Ops.get(disksOrder, 0, ""))

      nil
    end

    def GetItemID(t)
      t = deep_copy(t)
      Ops.get_string(
        Builtins.argsof(Ops.get_term(Builtins.argsof(t), 0) { Id("") }),
        0,
        ""
      )
    end

    def StoreDiskOrder(widget, event)
      event = deep_copy(event)
      disksOrder = Convert.convert(
        UI.QueryWidget(Id(:disks), :Items),
        :from => "any",
        :to   => "list <term>"
      )
      result = Builtins.maplist(disksOrder) { |t| GetItemID(t) }
      BootCommon.mbrDisk = Ops.get(result, 0, "")
      index = 0
      BootStorage.device_mapping = Builtins.listmap(result) do |d|
        indexs = Builtins.tostring(index)
        index = Ops.add(index, 1)
        { d => Builtins.sformat("hd%1", indexs) }
      end

      nil
    end

    def NewDevicePopup
      popup = VBox(
        VSpacing(1),
        # textentry header
        InputField(Id(:devname), Opt(:hstretch), _("&Device")),
        VSpacing(1),
        HBox(
          HStretch(),
          PushButton(Id(:ok), Opt(:key_F10, :default), Label.OKButton),
          HStretch(),
          PushButton(Id(:cancel), Opt(:key_F8), Label.CancelButton),
          HStretch()
        ),
        VSpacing(1)
      )
      UI.OpenDialog(popup)
      UI.SetFocus(:devname)
      pushed = UI.UserInput
      new_dev = UI.QueryWidget(Id(:devname), :Value)
      UI.CloseDialog

      pushed == :ok ? new_dev : ""
    end


    def HandleDiskOrder(widget, event)
      action = event["ID"]
      changed = false
      disksOrder = UI.QueryWidget(Id(:disks), :Items)
      current = UI.QueryWidget(Id(:disks), :CurrentItem)
      pos = 0
      while pos < disksOrder.size &&
          GetItemID(disksOrder[pos] || term(:Item, Id(""))) != current
        pos += 1
      end
      Builtins.y2debug("Calling handle disk order with action #{action} and selected on pos #{pos}")


      case action
      when :up
        changed = true
	# swap elements
        disksOrder.insert(pos - 1, disksOrder.delete_at(pos))
        pos -= 1
      when :down
        changed = true
	# swap elements
        disksOrder.insert(pos + 1, disksOrder.delete_at(pos))
        pos += 1
      when :delete
        changed = true
        disksOrder = Builtins.remove(disksOrder, pos)
        pos = pos > 0 ? pos -1 : 0
        UI.ChangeWidget(
          Id(:disks),
          :CurrentItem,
          GetItemID(disksOrder[pos] || term(:Item, Id("")))
        )
      when :add
        new_dev = NewDevicePopup()
        if new_dev != ""
          changed = true
          disksOrder << Item(Id(new_dev), new_dev)
        end
      end

      #disabling & enabling up/down, do it after change
      UI.ChangeWidget(Id(:up), :Enabled, pos > 0 && pos < disksOrder.size)
      UI.ChangeWidget(Id(:down), :Enabled, pos < disksOrder.size - 1)

      UI.ChangeWidget(Id(:disks), :Items, disksOrder) if changed

      nil
    end

    def ValidateDiskOrder(key, event)
      event = deep_copy(event)
      disksOrder = Convert.convert(
        UI.QueryWidget(Id(:disks), :Items),
        :from => "any",
        :to   => "list <term>"
      )
      return true if Ops.greater_than(Builtins.size(disksOrder), 0)
      Popup.Warning(_("Device map must contain at least one device"))
      false
    end

    def DisksOrderWidget
      contents = HBox(
        HSpacing(2),
        VBox(
          VSpacing(1),
          SelectionBox(Id(:disks), Opt(:notify), _("D&isks"), []),
          HBox(
            HStretch(),
            PushButton(Id(:add), Opt(:key_F3), Label.AddButton),
            PushButton(Id(:delete), Opt(:key_F5), Label.DeleteButton),
            HStretch()
          ),
          VSpacing(1)
        ),
        HSquash(
          VBox(
            VStretch(),
            PushButton(Id(:up), Opt(:hstretch), _("&Up")),
            PushButton(Id(:down), Opt(:hstretch), _("&Down")),
            VStretch()
          )
        ),
        HSpacing(2)
      )
      {
        "widget"            => :custom,
        "custom_widget"     => contents,
        "init"              => fun_ref(method(:InitDiskOrder), "void (string)"),
        "handle"            => fun_ref(
          method(:HandleDiskOrder),
          "symbol (string, map)"
        ),
        "store"             => fun_ref(
          method(:StoreDiskOrder),
          "void (string, map)"
        ),
        "help"              => Ops.get(@grub_help_messages, "disk_order", ""),
        "validate_type"     => :function,
        "validate_function" => fun_ref(
          method(:ValidateDiskOrder),
          "boolean (string, map)"
        )
      }
    end

    # Init function of a widget
    # @param [String] widget string widget key
    def InitBootLoaderLocationWidget(widget)
      boot_devices = BootStorage.getPartitionList(:boot, "grub")
      value = ""
      if BootCommon.VerifyMDArray
        UI.ChangeWidget(Id("enable_redundancy"), :Value,
          BootCommon.enable_md_array_redundancy
        )

        value = BootCommon.globals["boot_mbr"] == "true"
        UI.ChangeWidget(Id("boot_mbr"), :Value, value)
      else
        list_global_target_keys = [
          "boot_mbr",
          "boot_boot",
          "boot_root",
          "boot_extended"
        ]
        list_global_target_keys.each do |key|
          value = BootCommon.globals[key]
          if value && UI.WidgetExists(Id(key))
            UI.ChangeWidget(Id(key), :Value, value == "true" ? true : false) && UI.WidgetExists(Id(key))
          end
        end
        UI.ChangeWidget(Id("boot_custom_list"), :Items, boot_devices)
      end

      if !Builtins.haskey(BootCommon.globals, "boot_custom") ||
          Ops.get(BootCommon.globals, "boot_custom", "") == ""
        UI.ChangeWidget(Id("boot_custom_list"), :Enabled, false)
      else
        UI.ChangeWidget(Id("boot_custom"), :Value, true)
        UI.ChangeWidget(Id("boot_custom_list"), :Enabled, true)
        UI.ChangeWidget(
          Id("boot_custom_list"),
          :Value,
          Ops.get(BootCommon.globals, "boot_custom", "")
        )
      end

      nil
    end
    # handle function of a widget
    # @param [String] widget string widget key
    # @param [Hash] event map event that caused the operation
    # @return [Symbol]
    def HandleBootLoaderLocationWidget(widget, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      if ret == "boot_custom"
        if Convert.to_boolean(UI.QueryWidget(Id("boot_custom"), :Value))
          UI.ChangeWidget(Id("boot_custom_list"), :Enabled, true)
        else
          UI.ChangeWidget(Id("boot_custom_list"), :Enabled, false)
        end
      end
      nil
    end


    # Store function of a widget
    # @param [String] widget string widget key
    # @param [Hash] event map event that caused the operation
    def StoreBootLoaderLocationWidget(widget, event)
      event = deep_copy(event)
      if BootCommon.VerifyMDArray
        BootCommon.enable_md_array_redundancy = Convert.to_boolean(
          UI.QueryWidget(Id("enable_redundancy"), :Value)
        )
        Ops.set(
          BootCommon.globals,
          "boot_mbr",
          Convert.to_boolean(UI.QueryWidget(Id("boot_mbr"), :Value)) ? "true" : "false"
        )
      else
        list_global_target_keys = [
          "boot_mbr",
          "boot_boot",
          "boot_root",
          "boot_extended"
        ]
        Builtins.foreach(list_global_target_keys) do |key|
          value = UI.WidgetExists(Id(key) && UI.QueryWidget(Id(key), :Value))
          BootCommon.globals[key] = value.to_s
        end
      end
      if UI.QueryWidget(Id("boot_custom"), :Value)
        custom_value = UI.QueryWidget(Id("boot_custom_list"), :Value)
      else
        #bnc#544809 Custom Boot Partition cannot be deleted
        custom_value = ""
      end
      BootCommon.globals["boot_custom"] = custom_value

      nil
    end

    # FIXME: merge help text to one for BootLoaderLocationWidget
    #  Function merge help text from ../grub/helps.ycp
    #
    # @return [String] help text for widget BootLoaderLocationWidget
    def HelpBootLoaderLocationWidget
      ret = ""
      ret = Ops.get(@grub_help_messages, "boot_mbr", "")
      ret = Ops.add(ret, "\n")
      ret = Ops.add(ret, Ops.get(@grub_help_messages, "boot_custom", ""))
      ret = Ops.add(ret, "\n")
      if BootCommon.VerifyMDArray
        ret = Ops.add(
          ret,
          Ops.get(@grub_help_messages, "enable_redundancy", "")
        )
      else
        ret = Ops.add(ret, Ops.get(@grub_help_messages, "boot_root", ""))
        ret = Ops.add(ret, "\n")
        ret = Ops.add(ret, Ops.get(@grub_help_messages, "boot_boot", ""))
        ret = Ops.add(ret, "\n")
        ret = Ops.add(ret, Ops.get(@grub_help_messages, "boot_extended", ""))
      end
      ret
    end

    # Create Frame "Boot Loader Location"
    #
    # @return [Yast::Term] with widgets

    def grubBootLoaderLocationWidget
      if BootStorage.can_boot_from_partition
        partition_boot = BootStorage.BootPartitionDevice == BootStorage.RootPartitionDevice ?
          Left(CheckBox(Id("boot_root"), _("Boot from &Root Partition"))) :
          Left(CheckBox(Id("boot_boot"), _("Boo&t from Boot Partition")))
      else
        partition_boot = Empty()
      end

      boot_custom = [
      Left(
        CheckBox(
          Id("boot_custom"),
          Opt(:notify),
          _("C&ustom Boot Partition")
        )
      ),
      Left(
        ComboBox(
          Id("boot_custom_list"),
          Opt(:editable, :hstretch),
          "",
          []
        )
      )]

      contents = VBox(
        VSpacing(1),
        Frame(
          _("Boot Loader Location"),
          VBox(
            HBox(
              HSpacing(1),
              VBox(
                Left(
                  CheckBox(Id("boot_mbr"), _("Boot from &Master Boot Record"))
                ),
                partition_boot,
                BootStorage.ExtendedPartitionDevice ?
                  Left(
                    CheckBox(
                      Id("boot_extended"),
                      _("Boot from &Extended Partition")
                    )
                  ) :
                  Empty(),
                *boot_custom
              )
            )
          )
        ),
        VSpacing(1)
      )

      if !BootCommon.PartitionInstallable
        contents = VBox(
          Frame(
            _("Boot Loader Location"),
            VBox(
              HBox(
                HSpacing(1),
                VBox(
                  Left(
                    CheckBox(Id("boot_mbr"), _("Boot from &Master Boot Record"))
                  ),
                  *boot_custom,
                  VStretch()
                )
              )
            )
          ),
          VStretch()
        )
      end

      if BootCommon.VerifyMDArray
        contents = VBox(
          Frame(
            _("Boot Loader Location"),
            VBox(
              HBox(
                HSpacing(1),
                VBox(
                  Left(
                    CheckBox(Id("boot_mbr"), _("Boot from &Master Boot Record"))
                  ),
                  Left(
                    CheckBox(
                      Id("enable_redundancy"),
                      _("Enable Red&undancy for MD Array")
                    )
                  ),
                  *boot_custom,
                  VStretch()
                )
              )
            )
          ),
          VStretch()
        )
      end
      {
        "widget"        => :custom,
        "custom_widget" => contents,
        "init"          => fun_ref(
          method(:InitBootLoaderLocationWidget),
          "void (string)"
        ),
        "handle"        => fun_ref(
          method(:HandleBootLoaderLocationWidget),
          "symbol (string, map)"
        ),
        "store"         => fun_ref(
          method(:StoreBootLoaderLocationWidget),
          "void (string, map)"
        ),
        "help"          => HelpBootLoaderLocationWidget()
      }
    end
  end
end
