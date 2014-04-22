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
      items = []

      Builtins.foreach(BootCommon.sections) do |s|
        items = Builtins.add(
          items,
          Item(
            Id(Ops.get_string(s, "menuentry", "")),
            Ops.get_string(s, "menuentry", "")
          )
        )
      end

      UI.ChangeWidget(Id(widget), :Items, items)
      InitGlobalStr(widget)
      nil
    end

    # Init function for console
    # @param [String] widget
    def ConsoleInit(widget)
      enable = Ops.get(BootCommon.globals, "terminal", "") == "serial"
      UI.ChangeWidget(Id(:console_frame), :Value, enable)
      args = Ops.get(BootCommon.globals, "serial", "")
      UI.ChangeWidget(Id(:console_args), :Value, args)

      enable = Ops.get(BootCommon.globals, "terminal", "") == "gfxterm"
      UI.ChangeWidget(Id(:gfxterm_frame), :Value, enable)

      @vga_modes = Initrd.VgaModes if Builtins.size(@vga_modes) == 0

      vga_modes_sort = Builtins.sort(@vga_modes) do |a, b|
        if Ops.get_integer(a, "width", 0) == Ops.get_integer(b, "width", 0)
          next Ops.greater_than(
            Ops.get_integer(a, "height", 0),
            Ops.get_integer(b, "height", 0)
          )
        end
        Ops.greater_than(
          Ops.get_integer(a, "width", 0),
          Ops.get_integer(b, "width", 0)
        )
      end

      width = 0
      height = 0
      vga_modes_sort = Builtins.filter(vga_modes_sort) do |m|
        ret = false
        if width != Ops.get_integer(m, "width", 0) ||
            height != Ops.get_integer(m, "height", 0)
          ret = true
        end
        width = Ops.get_integer(m, "width", 0)
        height = Ops.get_integer(m, "height", 0)
        ret
      end

      items = Builtins.maplist(vga_modes_sort) do |m|
        mode2 = Builtins.sformat(
          "%1x%2",
          Ops.get_integer(m, "width", 0),
          Ops.get_integer(m, "height", 0)
        )
        Item(Id(mode2), mode2)
      end


      items = Builtins.prepend(
        items,
        Item(Id("auto"), _("Autodetect by grub2"))
      )
      UI.ChangeWidget(Id(:gfxmode), :Items, items)
      mode = Ops.get(BootCommon.globals, "gfxmode", "")

      # there's mode specified, use it
      UI.ChangeWidget(Id(:gfxmode), :Value, mode) if mode != ""

      UI.ChangeWidget(
        Id(:gfxtheme),
        :Value,
        Ops.get(BootCommon.globals, "gfxtheme", "")
      )

      nil
    end

    # Store function of a console
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    def ConsoleStore(widget, event)
      event = deep_copy(event)
      use_serial = Convert.to_boolean(
        UI.QueryWidget(Id(:console_frame), :Value)
      )
      use_gfxterm = Convert.to_boolean(
        UI.QueryWidget(Id(:gfxterm_frame), :Value)
      )

      if use_gfxterm && use_serial
        use_gfxterm = false
      elsif !use_gfxterm && !use_serial
        Ops.set(BootCommon.globals, "terminal", "console")
      end

      if use_serial
        Ops.set(BootCommon.globals, "terminal", "serial")
        console_value = Convert.to_string(
          UI.QueryWidget(Id(:console_args), :Value)
        )
        if console_value != ""
          Ops.set(BootCommon.globals, "serial", console_value)
        end
      else
        if Builtins.haskey(BootCommon.globals, "serial")
          BootCommon.globals = Builtins.remove(BootCommon.globals, "serial")
        end
      end

      Ops.set(BootCommon.globals, "terminal", "gfxterm") if use_gfxterm

      mode = Convert.to_string(UI.QueryWidget(Id(:gfxmode), :Value))
      Ops.set(BootCommon.globals, "gfxmode", mode) if mode != ""

      theme = Convert.to_string(UI.QueryWidget(Id(:gfxtheme), :Value))
      Ops.set(BootCommon.globals, "gfxtheme", theme)

      # FATE: #110038: Serial console
      # add or remove console key with value for sections
      BootCommon.HandleConsole2

      nil
    end

    def ConsoleHandle(widget, event)
      event = deep_copy(event)
      theme_dir = "/boot/grub2/themes/openSUSE"

      if SCR.Read(path(".target.size"), theme_dir) == -1
        theme_dir = "/boot/grub2"
      end

      file = UI.AskForExistingFile(
        theme_dir,
        "*.txt",
        _("Choose new graphical theme file")
      )

      UI.ChangeWidget(Id(:gfxtheme), :Value, file) if file != nil

      nil
    end

    def ConsoleContent
      VBox(
        CheckBoxFrame(
          Id(:gfxterm_frame),
          _("Use &graphical console"),
          true,
          HBox(
            HSpacing(2),
            ComboBox(
              Id(:gfxmode),
              Opt(:editable, :hstretch),
              _("&Console resolution"),
              [""]
            ),
            HBox(
              Left(
                InputField(
                  Id(:gfxtheme),
                  Opt(:hstretch),
                  _("&Console theme")
                )
              ),
              VBox(
                Left(Label("")),
                Left(
                  PushButton(
                    Id(:browsegfx),
                    Opt(:notify),
                    Label.BrowseButton
                  )
                )
              )
            ),
            HStretch()
          )
        ),
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
      )
    end

    def distributor_init(widget)
      distributor = BootCommon.globals["distributor"] || self.proposed_distributor
      if distributor == self.proposed_distributor
        UI.ChangeWidget(Id(:custom_distributor), :Value, false)
        UI.ChangeWidget(Id(:distributor), :Enabled, false)
        UI.ChangeWidget(Id(:distributor), :Value, Product.name)
      else
        UI.ChangeWidget(Id(:custom_distributor), :Value, true)
        UI.ChangeWidget(Id(:distributor), :Enabled, true)
        UI.ChangeWidget(Id(:distributor), :Value, distributor)
      end
    end

    def distributor_store(widget, event)
      use_custom = UI.QueryWidget(Id(:custom_distributor), :Value)
      if (!use_custom)
        BootCommon.globals["distributor"] = self.proposed_distributor
        return
      end
      value = UI.QueryWidget(Id(:distributor), :Value)
      BootCommon.globals["distributor"] = value
    end

    def distributor_content
      VBox(
        CheckBoxFrame(
          Id(:custom_distributor),
          _("Use &custom distributor"),
          true,
          HBox(
            HSpacing(2),
            InputField(
              Id(:distributor),
              Opt(:hstretch),
              _("&Distributor")
            ),
            HStretch()
          )
        )
      )
    end

    MASKED_PASSWORD = "**********"

    def grub2_pwd_store(key, event)
      usepass = UI.QueryWidget(Id(:use_pas), :Value)
      if !usepass
        # we are in proper module that can store password
        self.password = nil
        return
      end

      value = UI.QueryWidget(Id(:pw1), :Value)
      # special value as we do not know password, so it mean user do not change it
      if value == MASKED_PASSWORD
        self.password = ""
      else
        self.password = value
      end
    end

    def grub2_pwd_init(widget)
      passwd = GRUB2Pwd.new.used?
      if passwd
        UI.ChangeWidget(Id(:use_pas), :Value, true)
        UI.ChangeWidget(Id(:pw1), :Enabled, true)
        UI.ChangeWidget(Id(:pw1), :Value, MASKED_PASSWORD)
        UI.ChangeWidget(Id(:pw2), :Enabled, true)
        UI.ChangeWidget(Id(:pw2), :Value, MASKED_PASSWORD)
      else
        UI.ChangeWidget(Id(:use_pas), :Value, false)
        UI.ChangeWidget(Id(:pw1), :Enabled, false)
        UI.ChangeWidget(Id(:pw1), :Value, "")
        UI.ChangeWidget(Id(:pw2), :Enabled, false)
        UI.ChangeWidget(Id(:pw2), :Value, "")
      end
    end

    def Grub2Options
      grub2_specific = {
        "activate"        => CommonCheckboxWidget(
          Ops.get(@grub_descriptions, "activate", "activate"),
          Ops.get(@grub_help_messages, "activate", "")
        ),
        "generic_mbr"     => CommonCheckboxWidget(
          Ops.get(@grub_descriptions, "generic_mbr", "generic mbr"),
          Ops.get(@grub_help_messages, "generic_mbr", "")
        ),
        "hiddenmenu"      => CommonCheckboxWidget(
          Ops.get(@grub_descriptions, "hiddenmenu", "hidden menu"),
          Ops.get(@grub_help_messages, "hiddenmenu", "")
        ),
        "os_prober"       => CommonCheckboxWidget(
          Ops.get(@grub2_descriptions, "os_prober", "os_prober"),
          Ops.get(@grub2_help_messages, "os_prober", "")
        ),
        "append"          => CommonInputFieldWidget(
          Ops.get(@grub2_descriptions, "append", "append"),
          Ops.get(@grub2_help_messages, "append", "")
        ),
        "append_failsafe" => CommonInputFieldWidget(
          Ops.get(@grub2_descriptions, "append_failsafe", "append_failsafe"),
          Ops.get(@grub2_help_messages, "append_failsafe", "")
        ),
        "distributor"         => {
          "widget"            => :custom,
          "custom_widget"     => distributor_content,
          "init"              => fun_ref(
            method(:distributor_init),
            "void (string)"
          ),
          "store"             => fun_ref(
            method(:distributor_store),
            "void (string, map)"
          ),
        },
        "vgamode"         => {
          "widget" => :combobox,
          "label"  => Ops.get(@grub2_descriptions, "vgamode", "vgamode"),
          "opt"    => [:editable, :hstretch],
          "init"   => fun_ref(method(:VgaModeInit), "void (string)"),
          "store"  => fun_ref(method(:StoreGlobalStr), "void (string, map)"),
          "help"   => Ops.get(@grub2_help_messages, "vgamode", "")
        },
        "default"         => {
          "widget" => :combobox,
          "label"  => Ops.get(@grub_descriptions, "default", "default"),
          "opt"    => [:editable, :hstretch],
          "init"   => fun_ref(method(:DefaultEntryInit), "void (string)"),
          "store"  => fun_ref(method(:StoreGlobalStr), "void (string, map)"),
          "help"   => Ops.get(@grub_help_messages, "default", "")
        },
        "console"         => {
          "widget"        => :custom,
          "custom_widget" => ConsoleContent(),
          "init"          => fun_ref(method(:ConsoleInit), "void (string)"),
          "store"         => fun_ref(
            method(:ConsoleStore),
            "void (string, map)"
          ),
          "handle"        => fun_ref(
            method(:ConsoleHandle),
            "symbol (string, map)"
          ),
          "handle_events" => [:browsegfx],
          "help"          => Ops.get(@grub_help_messages, "serial", "")
        },
        "password"        => {
          "widget"            => :custom,
          "custom_widget"     => passwd_content,
          "init"              => fun_ref(
            method(:grub2_pwd_init),
            "void (string)"
          ),
          "handle"            => fun_ref(
            method(:HandlePasswdWidget),
            "symbol (string, map)"
          ),
          "store"             => fun_ref(
            method(:grub2_pwd_store),
            "void (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidatePasswdWidget),
            "boolean (string, map)"
          ),
          "help"              => @grub_help_messages["password"] || ""
        }
      }

      Convert.convert(
        Builtins.union(grub2_specific, CommonOptions()),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )
    end
  end
end
