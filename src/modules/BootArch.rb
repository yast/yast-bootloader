# encoding: utf-8

# File:
#      modules/BootArch.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific data for differnt architecturese
#      (as some architectures support multiple bootloaders, some bootloaders
#      support multiple architectures)
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Olaf Dabrunz <od@suse.de>
#
# $Id$
#
require "yast"

module Yast
  class BootArchClass < Module
    def main

      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "Kernel"
      Yast.import "Linuxrc"
      Yast.import "ProductFeatures"
      Yast.import "Stage"
    end

    # Get parameters for the default kernel
    # @param [String] resume string device to resume from (or empty not to set it)
    # @return [String] parameters for default kernel
    def DefaultKernelParams(resume)
      features = ProductFeatures.GetStringFeature(
        "globals",
        "additional_kernel_parameters"
      )
      kernel_cmdline = Kernel.GetCmdLine

      if Arch.i386 || Arch.x86_64
        ret = kernel_cmdline != "" ? Ops.add(kernel_cmdline, " ") : ""
        if resume != ""
          ret = Ops.add(ret, Builtins.sformat("resume=%1 ", resume))
        end
        ret = Ops.add(Ops.add(ret, features), " ") if features != ""
        if Builtins.regexpmatch(ret, "^(.* )?splash=[[:lower:]]+( .*)?$")
          ret = Builtins.regexpsub(
            ret,
            "^((.* ))?splash=[[:lower:]]+(( .*)?)$",
            "\\1 \\3"
          )
        end
        ret = Ops.add(ret, "splash=silent quiet showopts")
        return ret
      elsif Arch.ia64
        ret = kernel_cmdline != "" ? Ops.add(kernel_cmdline, " ") : ""
        ret = Ops.add(Ops.add(ret, features), " ") if features != ""
        ret = Ops.add(ret, "splash=silent quiet")

        # FIXME: this does not belong here, it cannot be tracked or maintained
        # and is undocumented
        # on SGI Altix change kernel default hash tables sizes
        if SCR.Read(path(".target.stat"), "/proc/sgi_sn") != {}
          ret = Ops.add(ret, " thash_entries=2097152")
        end
        return ret
      elsif Arch.s390
        file_desc = Convert.convert(
          SCR.Execute(path(".target.bash_output"), "echo $TERM"),
          :from => "any",
          :to   => "map <string, any>"
        )
        env_term = Ops.get_string(file_desc, "stdout", "")
        termparm = "hvc_iucv=8 TERM=dumb"
        if env_term == "linux\n"
          termparm = "TERM=linux console=ttyS0 console=ttyS1"
        end
        parameters = Builtins.sformat("%1 %2", features, termparm)
        if resume != ""
          parameters = Ops.add(
            parameters,
            Builtins.sformat(" resume=%1", resume)
          )
        end
        return parameters
      else
        Builtins.y2warning("Default kernel parameters not defined")
        return kernel_cmdline
      end
    end

    # Get parameters for the failsafe kernel
    # @return [String] parameters for failsafe kernel
    def FailsafeKernelParams
      ret = ""
      if Arch.i386
        ret = "showopts apm=off noresume nosmp maxcpus=0 edd=off powersaved=off nohz=off highres=off processor.max_cstate=1 nomodeset"
      elsif Arch.x86_64
        ret = "showopts apm=off noresume edd=off powersaved=off nohz=off highres=off processor.max_cstate=1 nomodeset"
      elsif Arch.ia64
        ret = "nohalt noresume powersaved=off"
      elsif Arch.s390
        ret = Ops.add(DefaultKernelParams(""), " noresume")
      else
        Builtins.y2warning("Parameters for Failsafe boot option not defined")
      end
      if Stage.initial
        ret = Ops.add(ret, " NOPCMCIA") if Linuxrc.InstallInf("NOPCMCIA") == "1"
      else
        saved_params = Convert.convert(
          SCR.Read(path(".target.ycp"), "/var/lib/YaST2/bootloader.ycp"),
          :from => "any",
          :to   => "map <string, any>"
        )
        ret = Ops.add(
          Ops.add(ret, " "),
          Ops.get_string(saved_params, "additional_failsafe_params", "")
        )
      end


      #B#352020 kokso: - Graphical failsafe mode
      #ret = ret + " 3";
      ret = Ops.add(ret, " x11failsafe")
      #B#352020 end
      ret
    end

    # Is VGA parameter setting available
    # @return true if vga= can be set
    def VgaAvailable
      Arch.i386 || Arch.x86_64 || Arch.ia64
    end

    # Is Suspend to Disk available?
    # @return true if STD is available
    def ResumeAvailable
      Arch.i386 || Arch.x86_64 || Arch.ia64 || Arch.s390
    end


    # Return architecture as string
    # @return [String] type of architecture e.g. "i386"
    def StrArch
      ret = Arch.architecture
      if ret == "ppc" || ret == "ppc64"
        if Arch.board_iseries
          ret = "iseries"
        elsif Arch.board_prep
          ret = "prep"
        elsif Arch.board_chrp
          ret = "chrp"
        elsif Arch.board_mac_new
          ret = "pmac"
        elsif Arch.board_mac_old
          ret = "pmac"
        else
          ret = "unknown"
        end
      end

      Builtins.y2milestone("Type of architecture: %1", ret)
      ret
    end

    publish :function => :DefaultKernelParams, :type => "string (string)"
    publish :function => :FailsafeKernelParams, :type => "string ()"
    publish :function => :VgaAvailable, :type => "boolean ()"
    publish :function => :ResumeAvailable, :type => "boolean ()"
    publish :function => :StrArch, :type => "string ()"
  end

  BootArch = BootArchClass.new
  BootArch.main
end
