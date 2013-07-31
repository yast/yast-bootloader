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
  class BootloaderClient < Client
    def main
      Yast.import "UI"
      textdomain "bootloader"

      Yast.import "BootCommon"
      Yast.import "Bootloader"
      Yast.import "CommandLine"
      Yast.import "Mode"
      Yast.import "RichText"

      Yast.include self, "bootloader/routines/wizards.rb"

      # the command line description map
      @cmdline = {
        "id"         => "bootloader",
        # command line help text for Bootloader module
        "help"       => _(
          "Boot loader configuration module"
        ),
        "guihandler" => fun_ref(method(:GuiHandler), "boolean ()"),
        "initialize" => fun_ref(Bootloader.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Bootloader.method(:Write), "boolean ()"),
        "actions"    => {
          "summary" => {
            "handler" => fun_ref(
              method(:BootloaderSummaryHandler),
              "boolean (map)"
            ),
            # command line help text for summary action
            "help"    => _(
              "Configuration summary of boot loader"
            )
          },
          "delete"  => {
            "handler" => fun_ref(
              method(:BootloaderDeleteHandler),
              "boolean (map)"
            ),
            # command line help text for delete action
            "help"    => _(
              "Delete a global option or option of a section"
            )
          },
          "set"     => {
            "handler" => fun_ref(method(:BootloaderSetHandler), "boolean (map)"),
            # command line help text for set action
            "help"    => _(
              "Set a global option or option of a section"
            )
          },
          "add"     => {
            "handler" => fun_ref(method(:BootloaderAddHandler), "boolean (map)"),
            # command line help text for add action
            "help"    => _(
              "Add a new section - please use interactive mode"
            )
          },
          "print"   => {
            "handler" => fun_ref(
              method(:BootloaderPrintHandler),
              "boolean (map)"
            ),
            # command line help text for print action
            "help"    => _(
              "Print value of specified option"
            )
          }
        },
        "options"    => {
          "section" => {
            # command line help text for an option
            "help" => _(
              "The name of the section"
            ),
            "type" => "string"
          },
          "option"  => {
            # command line help text for an option
            "help" => _(
              "The key of the option"
            ),
            "type" => "string"
          },
          "value"   => {
            # command line help text for an option
            "help" => _(
              "The value of the option"
            ),
            "type" => "string"
          }
        },
        "mappings"   => {
          "summary" => [],
          "delete"  => ["section", "option"],
          "set"     => ["section", "option", "value"],
          "add"     => ["section"],
          "print"   => ["section", "option"]
        }
      }

      Builtins.y2milestone("Starting bootloader configuration module")
      @skip_io = false
      @i = 0
      while Ops.less_than(@i, Builtins.size(WFM.Args))
        if path(".noio") == WFM.Args(@i) || ".noio" == WFM.Args(@i)
          @skip_io = true
        end
        @i = Ops.add(@i, 1)
      end

      @ret = CommandLine.Run(@cmdline)
      #    boolean ret = GuiHandler ();

      Builtins.y2milestone("Finishing bootloader configuration module")
      deep_copy(@ret)
    end

    # --------------------------------------------------------------------------
    # --------------------------------- cmd-line handlers

    # CommandLine handler for running GUI
    # @return [Boolean] true if settings were saved
    def GuiHandler
      ret = nil
      ret = BootloaderSequence()

      return false if ret == :abort || ret == :back || ret == :nil
      true
    end

    # Print summary of basic options
    # @param [Hash] options a list of parameters passed as args
    # @return [Boolean] false
    def BootloaderSummaryHandler(options)
      options = deep_copy(options)
      CommandLine.Print(
        RichText.Rich2Plain(
          Ops.add("<br>", Builtins.mergestring(Bootloader.Summary, "<br>"))
        )
      )
      false # do not call Write...
    end


    # Modify the boot loader section
    # @param [String] section string the section name
    # @param [String] key string the key to modify
    # @param [String] value string the value to set
    # @return [Boolean] true on success
    def BootloaderModifySection(section, key, value)
      if section == nil
        Ops.set(BootCommon.globals, key, value)
        return true
      else
        # change value in section specified by name in 'section'
        i = 0
        while Ops.less_than(i, Builtins.size(BootCommon.sections))
          if Ops.get_string(BootCommon.sections, [i, "name"], "") == section
            Ops.set(BootCommon.sections, [i, key], value)
            Ops.set(BootCommon.sections, [i, "__changed"], true)
            return true
          end
          i = Ops.add(i, 1)
        end

        # command line error report, %1 is section name
        CommandLine.Print(Builtins.sformat(_("Section %1 not found."), section))
        return false
      end
      false
    end

    # Set specified option in specified section
    # @param [Hash] options a list of parameters passed as args
    # @return [Boolean] true on success
    def BootloaderSetHandler(options)
      options = deep_copy(options)
      section = Ops.get_string(options, "section")
      option = Ops.get_string(options, "option")
      value = Ops.get(options, "value")
      if value == nil
        # command line error report
        CommandLine.Print(_("Value was not specified."))
        return false
      end
      BootloaderModifySection(section, option, Convert.to_string(value))
    end

    # Delete specified option in specified section
    # @param [Hash] options a list of parameters passed as args
    # @return [Boolean] true on success
    def BootloaderDeleteHandler(options)
      options = deep_copy(options)
      section = Ops.get_string(options, "section")
      if !Builtins.haskey(options, "option")
        # remove section specified by name in 'section'
        i = 0
        while Ops.less_than(i, Builtins.size(BootCommon.sections))
          if Ops.get_string(BootCommon.sections, [i, "name"], "") == section
            BootCommon.sections = Builtins.remove(BootCommon.sections, i)
            return true
          end
          i = Ops.add(i, 1)
        end

        # command line error report, %1 is section name
        CommandLine.Print(Builtins.sformat(_("Section %1 not found."), section))
        return false
      end
      option = Ops.get_string(options, "option")
      BootloaderModifySection(section, option, nil)
    end

    # Add a new bootloader section with specified name
    # @param [Hash] options a list of parameters passed as args
    # @return [Boolean] true on success
    def BootloaderAddHandler(options)
      options = deep_copy(options)
      if !CommandLine.Interactive
        CommandLine.Error(
          _("Add option is available only in commandline interactive mode")
        )
      end
      section = Ops.get_string(options, "section")
      if section == nil
        # command line error report
        CommandLine.Print(_("Section name must be specified."))
        return false
      end
      BootCommon.sections = Builtins.add(
        BootCommon.sections,
        { "name" => section }
      )

      nil
    end

    # Print the value of specified option of specified section
    # @param [Hash] options a list of parameters passed as args
    # @return [Boolean] true on success
    def BootloaderPrintHandler(options)
      options = deep_copy(options)
      section = Ops.get_string(options, "section")
      option = Ops.get_string(options, "option")
      if option == nil
        # command line error report
        CommandLine.Print(_("Option was not specified."))
        return false
      end
      value = nil
      if section == nil
        value = Ops.get(BootCommon.globals, option)
      else
        # change value in section specified by name in 'section'
        i = 0
        while Ops.less_than(i, Builtins.size(BootCommon.sections)) &&
            value == nil
          if Ops.get_string(BootCommon.sections, [i, "name"], "") == section
            value = Ops.get(BootCommon.sections, [i, option])
          end
          i = Ops.add(i, 1)
        end
      end
      if value == nil
        # command line error report
        CommandLine.Print(_("Specified option does not exist."))
      else
        # command line, %1 is the value of bootloader option
        CommandLine.Print(Builtins.sformat(_("Value: %1"), value))
      end
      false
    end
  end
end

Yast::BootloaderClient.new.main
