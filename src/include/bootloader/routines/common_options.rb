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
  module BootloaderRoutinesCommonOptionsInclude
    def initialize_bootloader_routines_common_options(include_target)
      textdomain "bootloader"

      Yast.include include_target, "bootloader/routines/common_helps.rb"
    end

    # Init function for widget value (InputField)
    # @param [String] widget any id of the widget
    def InitGlobalStr(widget)
      UI.ChangeWidget(
        Id(widget),
        :Value,
        Ops.get(BootCommon.globals, widget, "")
      )

      nil
    end

    # Store function of a widget (InputField)
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    def StoreGlobalStr(widget, _event)
      Ops.set(
        BootCommon.globals,
        widget,
        Convert.to_string(UI.QueryWidget(Id(widget), :Value))
      )

      nil
    end

    # Init function for widget value (CheckBox)
    # @param [String] widget any id of the widget
    def InitGlobalBool(widget)
      value = Ops.get(BootCommon.globals, widget, "false") == "true"
      UI.ChangeWidget(Id(widget), :Value, value)

      nil
    end

    # Init function for widget value (CheckBox)
    # @param [String] widget any id of the widget
    def StoreGlobalBool(widget, _event)
      value = Convert.to_boolean(UI.QueryWidget(Id(widget), :Value))
      Ops.set(BootCommon.globals, widget, value ? "true" : "false")

      nil
    end

    # Init function for widget value (IntField)
    # @param [String] widget any id of the widget
    def InitGlobalInt(widget)
      value = Builtins.tointeger(Ops.get(BootCommon.globals, widget, "0"))
      UI.ChangeWidget(Id(widget), :Value, value)

      nil
    end

    # Store function of a widget (IntField)
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    def StoreGlobalInt(widget, _event)
      value = Convert.to_integer(UI.QueryWidget(Id(widget), :Value))
      Ops.set(BootCommon.globals, widget, Builtins.tostring(value))

      nil
    end

    # Handle function of a widget (IntField + browse button)
    # @param [String] widget any widget key
    # @param [Hash] event map event description of event that occured
    # @return [Symbol] nil
    def HandleGlobalBrowse(widget, _event)
      current = Convert.to_string(UI.QueryWidget(Id(widget), :Value))
      # file open popup caption
      current = UI.AskForExistingFile(current, "*", _("Select File"))
      UI.ChangeWidget(Id(widget), :Value, current) if !current.nil?
      nil
    end

    # Generic widget of a checkbox
    # There is not defined valid function
    # if it is necessary create own definition of widget
    # @param string lable of widget
    # @param [String] help text for widget
    # @return [Hash{String => Object}] CWS widget
    def CommonCheckboxWidget(label, help)
      {
        "widget" => :checkbox,
        "label"  => label,
        "init"   => fun_ref(method(:InitGlobalBool), "void (string)"),
        "store"  => fun_ref(method(:StoreGlobalBool), "void (string, map)"),
        "help"   => help
      }
    end

    # Generic widget of a inputfield/textentry (widget)
    # There is not defined valid function
    # if it is necessary create own definition of widget
    # @param string lable of widget
    # @param [String] help text for widget
    # @return [Hash{String => Object}] CWS widget
    def CommonInputFieldWidget(label, help)
      {
        "widget" => :textentry,
        "label"  => label,
        "init"   => fun_ref(method(:InitGlobalStr), "void (string)"),
        "store"  => fun_ref(method(:StoreGlobalStr), "void (string, map)"),
        "help"   => help
      }
    end

    # Generic widget of a inputfield + browse button
    # There is not defined valid function
    # if it is necessary create own definition of widget
    # @param string lable of widget
    # @param [String] help text for widget
    # @param [String] id of widget
    # @return [Hash{String => Object}] CWS widget
    def CommonInputFieldBrowseWidget(label, help, id)
      browse = Ops.add("browse", id)
      {
        "widget"        => :custom,
        "custom_widget" => HBox(
          Left(InputField(Id(id), Opt(:hstretch), label)),
          VBox(
            Label(""),
            PushButton(Id(browse), Opt(:notify), Label.BrowseButton)
          )
        ),
        "init"          => fun_ref(method(:InitGlobalStr), "void (string)"),
        "store"         => fun_ref(
          method(:StoreGlobalStr),
          "void (string, map)"
        ),
        "handle"        => fun_ref(
          method(:HandleGlobalBrowse),
          "symbol (string, map)"
        ),
        "handle_events" => [browse],
        "help"          => help
      }
    end

    # Generic widget of a intfield (widget)
    # There is not defined valid function
    # if it is necessary create own definition of widget
    # @param string lable of widget
    # @param [String] help text for widget
    # @param integer minimal value
    # @param integer maximal value
    # @return [Hash{String => Object}] CWS widget
    def CommonIntFieldWidget(label, help, min, max)
      {
        "widget"  => :intfield,
        "label"   => label,
        "minimum" => min,
        "maximum" => max,
        "init"    => fun_ref(method(:InitGlobalStr), "void (string)"),
        "store"   => fun_ref(method(:StoreGlobalStr), "void (string, map)"),
        "help"    => help
      }
    end

    # Common widget of a Timeout
    # @return [Hash{String => Object}] CWS widget
    def TimeoutWidget
      {
        "widget"  => :intfield,
        "label"   => Ops.get(@common_descriptions, "timeout", "timeout"),
        "minimum" => -1,
        "maximum" => 600,
        "init"    => fun_ref(method(:InitGlobalInt), "void (string)"),
        "store"   => fun_ref(method(:StoreGlobalInt), "void (string, map)"),
        "help"    => Ops.get(@common_help_messages, "timeout", "")
      }
    end
    # Common widgets of global settings
    # @return [Hash{String => map<String,Object>}] CWS widgets
    def CommonOptions
      { "timeout" => TimeoutWidget() }
    end
  end
end
