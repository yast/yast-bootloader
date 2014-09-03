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

    def HandleTrusted(widget, event)
      event = deep_copy(event)
      value = Convert.to_boolean(UI.QueryWidget(Id(widget), :Value))
      nil
    end

    def TrustedWidget
      widget = CommonCheckboxWidget(
        Ops.get(@grub_descriptions, "trusted_grub", "trusted grub"),
        Ops.get(@grub_help_messages, "trusted_grub", "")
      )
      Ops.set(widget, "opt", [:notify])
      Ops.set(
        widget,
        "handle",
        fun_ref(method(:HandleTrusted), "symbol (string, map)")
      )
      deep_copy(widget)
    end

    # Init function of widget
    # @param [String] widget string id of the widget
    def InitPasswdWidget(widget)
      passwd = Ops.get(BootCommon.globals, "password", "")
      if passwd == nil || passwd == ""
        UI.ChangeWidget(Id(:use_pas), :Value, false)
        UI.ChangeWidget(Id(:pw1), :Enabled, false)
        UI.ChangeWidget(Id(:pw1), :Value, "")
        UI.ChangeWidget(Id(:pw2), :Enabled, false)
        UI.ChangeWidget(Id(:pw2), :Value, "")
      else
        UI.ChangeWidget(Id(:use_pas), :Value, true)
        UI.ChangeWidget(Id(:pw1), :Enabled, true)
        UI.ChangeWidget(Id(:pw1), :Value, "**********")
        UI.ChangeWidget(Id(:pw2), :Enabled, true)
        UI.ChangeWidget(Id(:pw2), :Value, "**********")
      end
      UI.ChangeWidget(Id(:use_pas), :Enable, false) if Mode.installation

      nil
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

    # Store function of a popup
    # @param [String] key any widget key
    # @param [Hash] event map event that caused the operation
    def StorePasswdWidget(key, event)
      event = deep_copy(event)
      password = nil
      usepass = Convert.to_boolean(UI.QueryWidget(Id(:use_pas), :Value))
      Builtins.y2milestone("Usepass: %1", usepass)
      if usepass
        if UI.QueryWidget(Id(:pw1), :Value) != "**********"
          password = Convert.to_string(UI.QueryWidget(Id(:pw1), :Value))
          password = MakeGRUBHash(password)
          if password != nil
            Ops.set(BootCommon.globals, "password", password) #TODO popup for error
          end
        end
      elsif Builtins.haskey(BootCommon.globals, "password")
        BootCommon.globals = Builtins.remove(BootCommon.globals, "password")
      end
      nil
    end

    def MakeGRUBHash(password)
      return password if password.include? "--md5"

      cmd = "echo \"md5crypt
        #{password}\" | grub --batch | grep Encrypted"

      result = SCR.execute(path(".target.bash_output"), cmd)

      # proper password contain special string $1$
      return nil unless result.include? "$1$"

      result.sub(/\AEncrypted:\s*(.*)\s*\z/, "--md5 \\1")
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


    # Build a map describing a widget
    # @return a map describing a widget
    def PasswordWidget
      {
        "widget"            => :custom,
        # frame
        "custom_widget"     => passwd_content,
        "init"              => fun_ref(
          method(:InitPasswdWidget),
          "void (string)"
        ),
        "handle"            => fun_ref(
          method(:HandlePasswdWidget),
          "symbol (string, map)"
        ),
        "store"             => fun_ref(
          method(:StorePasswdWidget),
          "void (string, map)"
        ),
        "validate_type"     => :function,
        "validate_function" => fun_ref(
          method(:ValidatePasswdWidget),
          "boolean (string, map)"
        ),
        "help"              => Ops.get(@grub_help_messages, "password", "")
      }
    end

    # Init function for console
    # @param [String] widget
    def InitConsole(widget)
      enable = Ops.get(BootCommon.globals, "terminal", "") == "serial"
      UI.ChangeWidget(Id(:console_frame), :Value, enable)
      args = Ops.get(BootCommon.globals, "serial", "")
      UI.ChangeWidget(Id(:console_args), :Value, args)

      nil
    end

    # Store function of a console
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    def StoreConsole(widget, event)
      event = deep_copy(event)
      use_serial = Convert.to_boolean(
        UI.QueryWidget(Id(:console_frame), :Value)
      )
      if use_serial
        Ops.set(BootCommon.globals, "terminal", "serial")
        console_value = Convert.to_string(
          UI.QueryWidget(Id(:console_args), :Value)
        )
        if console_value != ""
          Ops.set(BootCommon.globals, "serial", console_value)
        end
      else
        if Builtins.haskey(BootCommon.globals, "terminal")
          BootCommon.globals = Builtins.remove(BootCommon.globals, "terminal")
        end
        if Builtins.haskey(BootCommon.globals, "serial")
          BootCommon.globals = Builtins.remove(BootCommon.globals, "serial")
        end
      end
      # FATE: #110038: Serial console
      # add or remove console key with value for sections
      BootCommon.HandleConsole

      nil
    end

    # Handle function of  a console
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] nil
    def HandleConsole(widget, event)
      event = deep_copy(event)
      enable = Convert.to_boolean(UI.QueryWidget(Id(:enable_console), :Value))
      UI.ChangeWidget(Id(:console_args), :Enabled, enable)
      nil
    end

    # Common widget of a console
    # @return [Hash{String => Object}] CWS widget
    def ConsoleWidget
      {
        "widget"        => :custom,
        "custom_widget" => HBox(
          CheckBoxFrame(
            Id(:console_frame),
            _("Use &serial console"),
            true,
            HBox(
              HSpacing(2),
              InputField(
                Id(:console_args),
                Opt(:hstretch),
                _("&Console arguments")
              ),
              HStretch()
            )
          )
        ),
        "init"          => fun_ref(method(:InitConsole), "void (string)"),
        "handle"        => fun_ref(method(:HandleConsole), "void (string, map)"),
        "store"         => fun_ref(method(:StoreConsole), "void (string, map)"),
        "help"          => Ops.get(@grub_help_messages, "serial", "")
      }
    end

    def GrubOptions
      grub_specific = {
        "activate"         => CommonCheckboxWidget(
          Ops.get(@grub_descriptions, "activate", "activate"),
          Ops.get(@grub_help_messages, "activate", "")
        ),
        "debug"            => CommonCheckboxWidget(
          Ops.get(@grub_descriptions, "debug", "debug"),
          Ops.get(@grub_help_messages, "debug", "")
        ),
        "generic_mbr"      => CommonCheckboxWidget(
          Ops.get(@grub_descriptions, "generic_mbr", "generic mbr"),
          Ops.get(@grub_help_messages, "generic_mbr", "")
        ),
        "trusted_grub"     => TrustedWidget(),
        "hiddenmenu"       => CommonCheckboxWidget(
          Ops.get(@grub_descriptions, "hiddenmenu", "hidden menu"),
          Ops.get(@grub_help_messages, "hiddenmenu", "")
        ),
        "password"         => PasswordWidget(),
        "console"          => ConsoleWidget(),
      }
      Convert.convert(
        Builtins.union(grub_specific, CommonOptions()),
        :from => "map",
        :to   => "map <string, map <string, any>>"
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
      # once order is reviewed by user, BIOS IDs don't matter (bnc#880439)
      BootStorage.bois_id_missing = false

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
        if BootCommon.enable_md_array_redundancy
          UI.ChangeWidget(Id("enable_redundancy"), :Value, true)
        else
          UI.ChangeWidget(Id("enable_redundancy"), :Value, false)
        end

        value = Ops.get(BootCommon.globals, "boot_mbr")
        UI.ChangeWidget(Id("boot_mbr"), :Value, value == "true" ? true : false)
      else
        list_global_target_keys = [
          "boot_mbr",
          "boot_boot",
          "boot_root",
          "boot_extended"
        ]
        Builtins.foreach(list_global_target_keys) do |key|
          value = Ops.get(BootCommon.globals, key)
          if value != nil
            UI.ChangeWidget(Id(key), :Value, value == "true" ? true : false)
          end
        end
        UI.ChangeWidget(Id("boot_custom_list"), :Items, boot_devices)

        if BootStorage.BootPartitionDevice == BootStorage.RootPartitionDevice
          UI.ChangeWidget(Id("boot_boot"), :Enabled, false)
        else
          UI.ChangeWidget(Id("boot_boot"), :Enabled, true)
        end

        if BootStorage.ExtendedPartitionDevice != nil
          UI.ChangeWidget(Id("boot_extended"), :Enabled, true)
        else
          UI.ChangeWidget(Id("boot_extended"), :Enabled, false)
        end
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
          value = Convert.to_boolean(UI.QueryWidget(Id(key), :Value)) ? "true" : "false"
          Ops.set(BootCommon.globals, key, value)
        end
      end
      if Convert.to_boolean(UI.QueryWidget(Id("boot_custom"), :Value))
        Ops.set(
          BootCommon.globals,
          "boot_custom",
          Convert.to_string(UI.QueryWidget(Id("boot_custom_list"), :Value))
        )
      else
        #bnc#544809 Custom Boot Partition cannot be deleted
        Ops.set(BootCommon.globals, "boot_custom", "")
      end

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
                  Empty()
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
                  ),
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
                  ),
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

    # Handle function of a widget
    # @param [String] widget string widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] to return to wizard sequencer, or nil
    def InstDetailsButtonHandle(widget, event)
      event = deep_copy(event)
      :inst_details
    end


    def grubInstalationDetials
      {
        "widget"        => :push_button,
        # push button
        "label"         => _("Boot Loader Installation &Details"),
        "handle_events" => ["inst_details"],
        "handle"        => fun_ref(
          method(:InstDetailsButtonHandle),
          "symbol (string, map)"
        ),
        "help"          => InstDetailsHelp()
      }
    end
  end
end
