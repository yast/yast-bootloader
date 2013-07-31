# encoding: utf-8

# File:
#      bootloader_auto.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Bootloader autoinstallation preparation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  class BootloaderAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "bootloader"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("bootloader auto started")

      Yast.import "Bootloader"
      Yast.import "BootCommon"
      Yast.import "Initrd"
      Yast.import "Progress"
      Yast.import "Mode"

      Yast.include self, "bootloader/routines/autoinstall.rb"
      Yast.include self, "bootloader/routines/wizards.rb"

      @progress_orig = Progress.set(false)


      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Import"
        @ret = Bootloader.Import(
          AI2Export(
            Convert.convert(@param, :from => "map", :to => "map <string, any>")
          )
        )
      # Create a summary
      # return string
      elsif @func == "Summary"
        @ret = Ops.add(
          Ops.add(
            "<UL>",
            Builtins.mergestring(Builtins.maplist(Bootloader.Summary) do |l|
              Ops.add("<LI>", l)
            end, "\n")
          ),
          "</UL>"
        )
      # did configuration changed
      # return boolean
      elsif @func == "GetModified"
        @ret = BootCommon.changed
      # set configuration as changed
      # return boolean
      elsif @func == "SetModified"
        BootCommon.changed = true
        @ret = true
      # Reset configuration
      # return map or list
      elsif @func == "Reset"
        Bootloader.Reset
        @ret = {}
      # Change configuration
      # return symbol (i.e. `finish || `accept || `next || `cancel || `abort)
      elsif @func == "Change"
        @ret = BootloaderAutoSequence()
        return deep_copy(@ret)
      # Return configuration data
      # return map or list
      elsif @func == "Export"
        @ret = Export2AI(
          Convert.convert(
            Bootloader.Export,
            :from => "map",
            :to   => "map <string, any>"
          )
        )
      # Write configuration data
      # return boolean
      elsif @func == "Write"
        @ret = Bootloader.Write
      elsif @func == "Read"
        Initrd.Read
        @ret = Bootloader.Read
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end
      Progress.set(@progress_orig)

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("bootloader_auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::BootloaderAutoClient.new.main
