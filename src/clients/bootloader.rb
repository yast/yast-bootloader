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
              "Delete a global option"
            )
          },
          "set"     => {
            "handler" => fun_ref(method(:BootloaderSetHandler), "boolean (map)"),
            # command line help text for set action
            "help"    => _(
              "Set a global option"
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
          "delete"  => ["option"],
          "set"     => ["option", "value"],
          "print"   => ["option"]
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
    # @param [String] key string the key to modify
    # @param [String] value string the value to set
    # @return [Boolean] true on success
    def BootloaderModify(key, value)
      BootCommon.globals[key, value]
      return true
    end

    # Set specified option in specified section
    # @param [Hash] options a list of parameters passed as args
    # @return [Boolean] true on success
    def BootloaderSetHandler(options)
      option = options["option"]
      value = options["value"]
      if value.nil?
        # command line error report
        CommandLine.Print(_("Value was not specified."))
        return false
      end
      BootloaderModify(option, value.to_s)
    end

    # Delete specified option in specified section
    # @param [Hash] options a list of parameters passed as args
    # @return [Boolean] true on success
    def BootloaderDeleteHandler(options)
      option = options["option"]
      BootloaderModifySection(section, option, nil)
    end

    # Print the value of specified option of specified section
    # @param [Hash] options a list of parameters passed as args
    # @return [Boolean] true on success
    def BootloaderPrintHandler(options)
      options = deep_copy(options)
      option = options["option"]
      if option == nil
        # command line error report
        CommandLine.Print(_("Option was not specified."))
        return false
      end
      value = BootCommon.globals[option]
      if value == nil
        # command line error report
        CommandLine.Print(_("Specified option does not exist."))
      else
        # command line, %1 is the value of bootloader option
        CommandLine.Print(_("Value: %s") % value))
      end
      false
    end
  end
end

Yast::BootloaderClient.new.main
