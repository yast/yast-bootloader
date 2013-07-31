# encoding: utf-8

# File:
#      bootloader/routines/inst_bootloader.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Functions to write "dummy" config files for kernel
#
# Authors:
#      Jozef Uhliarik <juhliarik@suse.cz>
#
#
module Yast
  class InstLiloConvertClient < Client
    def main
      Yast.import "UI"

      textdomain "bootloader"


      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Installation"
      Yast.import "GetInstArgs"
      Yast.import "Mode"
      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Pkg"
      Yast.import "Arch"
      Yast.import "BootGRUB"
      Yast.import "PackagesProposal"

      Builtins.y2milestone("starting inst_lilo_convert")




      if GetInstArgs.going_back # going backwards?
        return :auto # don't execute this once more
      end

      if Mode.update && checkArch
        # save some sysconfig variables
        # register new agent pointing into the mounted filesystem
        @sys_agent = path(".target.sysconfig.bootloader")

        @target_sysconfig_path = Ops.add(
          Installation.destdir,
          "/etc/sysconfig/bootloader"
        )
        SCR.RegisterAgent(
          path(".target.sysconfig.bootloader"),
          term(:ag_ini, term(:SysConfigFile, @target_sysconfig_path))
        )

        @bl = Convert.to_string(
          SCR.Read(Builtins.add(@sys_agent, path(".LOADER_TYPE")))
        )

        @convert_question = VBox(
          HBox(
            HStretch(),
            RadioButtonGroup(
              Id(:convert),
              HSquash(
                VBox(
                  Left(
                    Label(
                      "LILO is not supported. The recommended option is select convert LILO to GRUB"
                    )
                  ),
                  Left(Label("Do you want convert settings and install GRUB?")),
                  Left(RadioButton(Id("lilo"), _("Stay &LILO"))),
                  Left(
                    RadioButton(
                      Id("grub"),
                      _("Convert Settings and Install &GRUB"),
                      true
                    )
                  )
                )
              )
            ),
            HStretch()
          )
        )
        @ret = nil
        if @bl == "lilo"
          Wizard.CreateDialog
          Wizard.SetDesktopIcon("bootloader")
          Wizard.SetContentsButtons(
            "Converting LILO to GRUB",
            @convert_question,
            _(
              "LILO is not supported. The recommended option is select convert LILO to GRUB"
            ),
            Label.BackButton,
            Label.NextButton
          )
          UI.ChangeWidget(Id(:abort), :Label, Label.CancelButton)
          UI.ChangeWidget(Id(:abort), :Enabled, false)

          while true
            @ret = UI.UserInput
            @current = Convert.to_string(
              UI.QueryWidget(Id(:convert), :CurrentButton)
            )
            # One of those dialog buttons have been pressed
            if @ret == :next
              selectPackage
              convertSettings
              SCR.Write(Builtins.add(@sys_agent, path(".LOADER_TYPE")), "grub")
              SCR.Write(@sys_agent, nil)
            end
            break
          end
          UI.CloseDialog
        end

        return :back if @ret == :back

        return :next if @ret == :next
      end

      Builtins.y2milestone("finish inst_lilo_convert")

      :auto
    end

    def selectPackage
      PackagesProposal.AddResolvables("yast2-bootloader", :package, ["grub"])

      nil
    end

    def convertSettings
      lilo_conf = Convert.to_string(
        WFM.Read(
          path(".local.string"),
          Ops.add(Installation.destdir, "/etc/lilo.conf")
        )
      )
      BootCommon.InitializeLibrary(true, "lilo")
      BootCommon.setLoaderType("lilo")
      new_files = {}
      Ops.set(new_files, "/etc/lilo.conf", lilo_conf)
      Builtins.y2milestone("/etc/lilo.conf : %1", new_files)
      BootCommon.SetFilesContents(new_files)

      sec = BootCommon.GetSections

      BootCommon.sections = deep_copy(sec)
      BootCommon.globals = BootCommon.GetGlobal

      BootCommon.InitializeLibrary(true, "grub")
      BootCommon.setLoaderType("grub")

      BootStorage.ProposeDeviceMap
      BootGRUB.Propose


      BootCommon.SetDeviceMap(BootStorage.device_mapping)
      BootCommon.SetSections(sec)
      BootCommon.SetGlobal(BootCommon.globals)



      tmp_files = BootCommon.GetFilesContents

      Builtins.y2milestone("new content file: %1", tmp_files)
      Builtins.foreach(tmp_files) do |file, content|
        last = Builtins.findlastof(file, "/")
        path_file = Builtins.substring(file, 0, last)
        WFM.Execute(
          path(".local.mkdir"),
          Ops.add(Installation.destdir, path_file)
        )
        Builtins.y2milestone("writing file: %1", file)
        WFM.Write(
          path(".local.string"),
          Ops.add(Installation.destdir, file),
          content
        )
      end

      nil
    end


    def checkArch
      ret = false
      ret = true if Arch.x86_64 || Arch.i386

      if ret
        Builtins.y2milestone(
          "inst_lilo_convert - supported architecture for converting LILO -> GRUB"
        )
      else
        Builtins.y2milestone(
          "inst_lilo_convert - UNsupported architecture for converting LILO -> GRUB"
        )
      end
      ret
    end
  end
end

Yast::InstLiloConvertClient.new.main
