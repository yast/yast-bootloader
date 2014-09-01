# encoding: utf-8

# File:
#      include/bootloader/routines/ui.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      User interface for bootloader installation/configuration
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  module BootloaderRoutinesDialogsInclude
    def initialize_bootloader_routines_dialogs(include_target)
      Yast.import "UI"
      textdomain "bootloader"

      Yast.import "BootCommon"
      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Bootloader"
      Yast.import "Stage"

      Yast.include include_target, "bootloader/routines/popups.rb"
      Yast.include include_target, "bootloader/routines/section_widgets.rb"
      Yast.include include_target, "bootloader/routines/global_widgets.rb"
      Yast.include include_target, "bootloader/grub2/dialogs.rb"


      @return_tab = "sections"
    end

    # Test for abort.
    # @return true if abort was pressed
    def testAbort
      return false if Mode.commandline
      if :abort == UI.PollInput
        UI.CloseDialog if !Stage.initial
        return true
      end
      false
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Bootloader.test_abort = fun_ref(method(:testAbort), "boolean ()")
      Wizard.RestoreHelp(getInitProgressHelp)
      ret = Bootloader.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      if !Stage.initial
        Bootloader.test_abort = fun_ref(method(:testAbort), "boolean ()")
      end
      Wizard.RestoreHelp(getSaveProgressHelp)
      ret = Bootloader.Write
      ret ? :next : :abort
    end


    # Run dialog for kernel section editation
    # @return [Symbol] for wizard sequencer
    def MainDialog
      Builtins.y2milestone("Running Main Dialog")
      lt = Bootloader.getLoaderType
      contents = VBox("tab")

      if lt != "grub2" && lt != "grub2-efi"
        contents = Builtins.add(contents, Right("adv_button"))
      end

      # F#300779 - Install diskless client (NFS-root)
      # kokso: additional warning that root partition is nfs type -> bootloader will not be installed
      device = BootCommon.getBootDisk

      if device == "/dev/nfs" && Mode.installation
        Popup.Message(
          _(
            "The boot partition is of type NFS. Bootloader cannot be installed."
          )
        )
        Builtins.y2milestone(
          "dialogs::MainDialog() -> Boot partition is nfs type, bootloader will not be installed."
        )
        return :next
      end
      # F#300779: end

      widget_names = lt == "grub2" || lt == "grub2-efi" ?
        ["tab"] :
        ["tab", "adv_button"]
      widget_descr = {}

      widget_descr = Convert.convert(
        Builtins.union(CommonGlobalWidgets(), Bootloader.blWidgetMaps),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )

      Ops.set(
        widget_descr,
        "tab",
        CWMTab.CreateWidget(
          {
            "tab_order"    => lt == "grub2" || lt == "grub2-efi" ?
              ["boot_code_tab", "kernel_tab", "bootloader_tab"] :
              ["sections", "installation"],
            "tabs"         => lt == "grub2" || lt == "grub2-efi" ?
              Grub2TabDescr() :
              TabsDescr(),
            "widget_descr" => widget_descr,
            "initial_tab"  => lt == "grub2" || lt == "grub2-efi" ? "boot_code_tab" : @return_tab
          }
        )
      )
      Ops.set(widget_descr, ["tab", "no_help"], "")

      # dialog caption
      caption = _("Boot Loader Settings")
      ret = CWM.ShowAndRun(
        {
          "widget_descr"       => widget_descr,
          "widget_names"       => widget_names,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => "",
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => @global_handlers
        }
      )
      if ret != :back && ret != :abort && ret != :cancel
        @return_tab = CWMTab.LastTab
        @return_tab = "installation" if @return_tab.include? "tab" #workaround different tab set for grub2
      end
      ret
    end

    # Run dialog with detailed settings
    # @param [String] type string specification of the type of detail settings
    # @return [Symbol] for wizard sequencer
    def DetailsDialog(type)
      dialogs = Bootloader.blDialogs
      if !Builtins.haskey(dialogs, type)
        Report.Message(
          # message
          _("There are no options to set for the current boot loader.")
        )
        return :back
      end
      dialog = Ops.get(dialogs, type)
      dialog.call
    end

    # Run dialog for kernel section editation
    # @return [Symbol] for wizard sequencer
    def KernelSectionDialog
      Builtins.y2milestone("Running kernel section dialog")
      lt = Bootloader.getLoaderType
      contents = HBox(
        HSpacing(2),
        VBox(
          VStretch(),
          # heading
          Left(Heading(_("Kernel Section"))),
          VSpacing(1),
          "name",
          VStretch(),
          # frame
          Frame(
            _("Section Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                HBox(Left("noverifyroot"), HSpacing(2), Left("enable_selinux")),
                "image",
                "initrd",
                HBox(HWeight(1, "root"), HWeight(1, "vgamode")),
                "append",
                VSpacing(1)
              ),
              HSpacing(2)
            )
          ),
          VStretch()
        ),
        HSpacing(2)
      )

      widget_names = [
        "name",
        "image",
        "initrd",
        "root",
        "vgamode",
        "append",
        "noverifyroot",
        "enable_selinux"
      ]

      widget_descr = Builtins.union(CommonSectionWidgets(), Bootloader.blWidgetMaps)

      # dialog caption
      caption = _("Boot Loader Settings: Section Management")
      CWM.ShowAndRun(
        {
          "widget_descr"       => widget_descr,
          "widget_names"       => widget_names,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => @section_handlers
        }
      )
    end

    # Run dialog for kernel section editation
    # @return [Symbol] for wizard sequencer
    def PpcIseriesKernelSectionDialog
      Builtins.y2milestone("Running kernel section dialog")
      contents = HBox(
        HSpacing(2),
        VBox(
          VStretch(),
          # heading
          Left(Heading(_("Kernel Section"))),
          VSpacing(1),
          "name",
          VStretch(),
          # frame
          Frame(
            _("Section Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                HBox(Left("optional"), HSpacing(2), Left("enable_selinux")),
                "image",
                "initrd",
                "root",
                "append",
                Left("copy"),
                VSpacing(1)
              ),
              HSpacing(2)
            )
          ),
          VStretch()
        ),
        HSpacing(2)
      )

      widget_names = [
        "name",
        "image",
        "initrd",
        "root",
        "optional",
        "append",
        "copy",
        "enable_selinux"
      ]

      widget_descr = {}
      widget_descr = Convert.convert(
        Builtins.union(CommonGlobalWidgets(), CommonSectionWidgets()),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )


      # dialog caption
      caption = _("Boot Loader Settings: Section Management")
      CWM.ShowAndRun(
        {
          "widget_descr"       => widget_descr,
          "widget_names"       => widget_names,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => @section_handlers
        }
      )
    end
    # Run dialog for kernel section editation
    # @return [Symbol] for wizard sequencer
    def PpcKernelSectionDialog
      Builtins.y2milestone("Running kernel section dialog")
      contents = HBox(
        HSpacing(2),
        VBox(
          VStretch(),
          # heading
          Left(Heading(_("Kernel Section"))),
          VSpacing(1),
          "name",
          VStretch(),
          # frame
          Frame(
            _("Section Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                HBox(Left("optional"), HSpacing(2), Left("enable_selinux")),
                "image",
                "initrd",
                "root",
                "append",
                VSpacing(1)
              ),
              HSpacing(2)
            )
          ),
          VStretch()
        ),
        HSpacing(2)
      )

      widget_names = [
        "name",
        "image",
        "initrd",
        "root",
        "optional",
        "append",
        "enable_selinux"
      ]

      widget_descr = {}
      widget_descr = Convert.convert(
        Builtins.union(CommonGlobalWidgets(), CommonSectionWidgets()),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )


      # dialog caption
      caption = _("Boot Loader Settings: Section Management")
      CWM.ShowAndRun(
        {
          "widget_descr"       => widget_descr,
          "widget_names"       => widget_names,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => @section_handlers
        }
      )
    end

    def XenSectionDialog
      Builtins.y2milestone("Running kernel section dialog")
      lt = Bootloader.getLoaderType
      contents = HBox(
        HSpacing(2),
        VBox(
          VStretch(),
          # heading
          Left(Heading(_("Xen Section"))),
          VSpacing(1),
          "name",
          VStretch(),
          # frame
          Frame(
            _("Section Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                "xen",
                "image",
                "initrd",
                HBox(HWeight(1, "root"), HWeight(1, "vgamode")),
                "append",
                "xen_append",
                VSpacing(1)
              ),
              HSpacing(2)
            )
          ),
          VStretch()
        ),
        HSpacing(2)
      )

      widget_names = [
        "name",
        "image",
        "initrd",
        "root",
        "vgamode",
        "append",
        "xen_append",
        "xen"
      ]
      widget_descr = Builtins.union(CommonSectionWidgets(), Bootloader.blWidgetMaps)
      # dialog caption
      caption = _("Boot Loader Settings: Section Management")
      CWM.ShowAndRun(
        {
          "widget_descr"       => widget_descr,
          "widget_names"       => widget_names,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => @section_handlers
        }
      )
    end

    def GrubMenuSectionDialog
      Builtins.y2milestone("Running kernel section dialog")
      lt = Bootloader.getLoaderType
      contents = HBox(
        HSpacing(2),
        VBox(
          VStretch(),
          # heading
          Left(Heading(_("Menu Section"))),
          VSpacing(1),
          "name",
          VStretch(),
          # frame
          Frame(
            _("Section Settings"),
            HBox(
              HSpacing(2),
              VBox(VSpacing(1), "root", "configfile", VSpacing(1)),
              HSpacing(2)
            )
          ),
          VStretch()
        ),
        HSpacing(2)
      )

      widget_names = ["name", "root", "configfile"]
      widget_descr = {}
      widget_descr = Convert.convert(
        Builtins.union(CommonGlobalWidgets(), CommonSectionWidgets()),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )
      # dialog caption
      caption = _("Boot Loader Settings: Section Management")
      CWM.ShowAndRun(
        {
          "widget_descr"       => widget_descr,
          "widget_names"       => widget_names,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => @section_handlers
        }
      )
    end

    def DumpSectionDialog
      Builtins.y2milestone("Running kernel section dialog")
      contents = HBox(
        HSpacing(2),
        VBox(
          VStretch(),
          # heading
          Left(Heading(_("Dump Section"))),
          VSpacing(1),
          "name",
          VStretch(),
          # frame
          Frame(
            _("Section Settings"),
            HBox(
              HSpacing(2),
              VBox(VSpacing(1), "target", "dumpto", "dumptofs", VSpacing(1)),
              HSpacing(2)
            )
          ),
          VStretch()
        ),
        HSpacing(2)
      )

      widget_names = ["name", "target", "dumpto", "dumptofs"]
      widget_descr = {}
      widget_descr = Convert.convert(
        Builtins.union(CommonGlobalWidgets(), CommonSectionWidgets()),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )
      # dialog caption
      caption = _("Boot Loader Settings: Section Management")
      CWM.ShowAndRun(
        {
          "widget_descr"       => widget_descr,
          "widget_names"       => widget_names,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => @section_handlers
        }
      )
    end

    # TODO DROP it
    def MenuSectionDialog
      nil
    end

    def PPCChainloaderSectionDialog
      Builtins.y2milestone("Running chainloader section dialog")
      lt = Bootloader.getLoaderType
      contents = HBox(
        HSpacing(4),
        VBox(
          # label
          Left(Heading(_("Other System Section"))),
          VSpacing(2),
          "name",
          VStretch(),
          # part two - section settings
          HBox(
            # frame
            Frame(
              _("Section Settings"),
              HBox(
                HSpacing(2),
                VBox(VSpacing(2), Left("other"), VSpacing(2)),
                HSpacing(2)
              )
            )
          ),
          VStretch()
        ),
        HSpacing(4)
      )

      widget_names = ["name", "other"]
      widget_descr = {}

      widget_descr = Convert.convert(
        Builtins.union(CommonGlobalWidgets(), CommonSectionWidgets()),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )


      # dialog caption
      caption = _("Boot Loader Settings: Section Management")
      CWM.ShowAndRun(
        {
          "widget_descr"       => widget_descr,
          "widget_names"       => widget_names,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => @section_handlers
        }
      )
    end
    # Run dialog for kernel section editation
    # @return [Symbol] for wizard sequencer
    def CommonChainloaderSectionDialog
      Builtins.y2milestone("Running chainloader section dialog")
      lt = Bootloader.getLoaderType
      contents = HBox(
        HSpacing(4),
        VBox(
          # label
          Left(Heading(_("Other System Section"))),
          VSpacing(2),
          "name",
          VStretch(),
          # part two - section settings
          HBox(
            # frame
            Frame(
              _("Section Settings"),
              HBox(
                HSpacing(2),
                VBox(
                  VSpacing(2),
                  Left("chainloader"),
                  Left("makeactive"),
                  Left("noverifyroot"),
                  Left("remap"),
                  Left(HSquash("blockoffset")),
                  VSpacing(2)
                ),
                HSpacing(2)
              )
            )
          ),
          VStretch()
        ),
        HSpacing(4)
      )

      widget_names = [
        "name",
        "chainloader",
        "makeactive",
        "noverifyroot",
        "remap",
        "blockoffset"
      ]

      widget_descr = Builtins.union(CommonGlobalWidgets(), Bootloader.blWidgetMaps)

      # dialog caption
      caption = _("Boot Loader Settings: Section Management")
      CWM.ShowAndRun(
        {
          "widget_descr"       => widget_descr,
          "widget_names"       => widget_names,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => @section_handlers
        }
      )
    end

    def ChainloaderSectionDialog
      return CommonChainloaderSectionDialog()
    end

    # Run dialog for kernel section editation
    # @return [Symbol] for wizard sequencer
    def AddNewSectionDialog
      Builtins.y2milestone("Running new section dialog")
      lt = Bootloader.getLoaderType
      contents = HBox(
        HStretch(),
        VBox(VStretch(), "section_type", VStretch()),
        HStretch()
      )

      widget_names = ["section_type"]
      widget_descr = Convert.convert(
        Builtins.union(CommonGlobalWidgets(), CommonSectionWidgets()),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )

      # dialog caption
      caption = _("Boot Loader Settings: Section Management")
      CWM.ShowAndRun(
        {
          "widget_descr" => widget_descr,
          "widget_names" => widget_names,
          "contents"     => contents,
          "caption"      => caption,
          "back_button"  => Label.BackButton,
          "abort_button" => Label.CancelButton,
          "next_button"  => Label.NextButton
        }
      )
    end

    # Switch the section type to be edited
    # @return [Symbol] for wizard sequencer to determine which dialog to show
    def EditSectionSwitch
      type = Ops.get_string(BootCommon.current_section, "type", "")
      return :chainloader if type == "chainloader" || type == "other"
      return :xen if type == "xen"
      return :menus if type == "menu"
      return :dump if type == "dump"
      if type == "image"
        return :kernel
      else
        return :kernel
      end
    end

    # Store the modified section
    # @return [Symbol] always `next
    def StoreSection
      Ops.set(BootCommon.current_section, "__changed", true)
      if Ops.get_string(BootCommon.current_section, "type", "") == "xen"
        BootCommon.current_section = Convert.convert(
          Builtins.union(
            {
              # bug #400526 there is not xenpae anymore...
              "xen"        => "/boot/xen.gz",
              "xen_append" => ""
            },
            BootCommon.current_section
          ),
          :from => "map",
          :to   => "map <string, any>"
        )
      end
      Builtins.y2milestone(
        "Storing section: index:  %1, contents: %2",
        BootCommon.current_section_index,
        BootCommon.current_section
      )
      if BootCommon.current_section_index == -1
        BootCommon.sections = Builtins.add(
          BootCommon.sections,
          BootCommon.current_section
        )
      else
        Ops.set(
          BootCommon.sections,
          BootCommon.current_section_index,
          BootCommon.current_section
        )
      end
      :next
    end

    # Run dialog
    # @return [Symbol] for wizard sequencer
    def runEditFilesDialog
      Bootloader.blSave(false, false, false)
      files = BootCommon.GetFilesContents
      defaultv = Ops.get(files, "default", "")
      files = Builtins.filter(files) { |k, v| k != "default" }
      filenames = []
      Builtins.foreach(files) { |k, v| filenames = Builtins.add(filenames, k) }
      cb = nil
      if Ops.greater_than(Builtins.size(files), 1)
        cb = ComboBox(
          Id(:filename),
          Opt(:notify, :hstretch),
          # combobox label
          _("&Filename"),
          filenames
        )
      else
        # label. %1 is name of file (eg. /etc/lilo.conf
        cb = Left(
          Label(
            Builtins.sformat(
              _("Filename: %1"),
              Ops.get_string(filenames, 0, "")
            )
          )
        )
      end

      contents = HBox(
        HSpacing(2),
        VBox(
          VSpacing(2),
          cb,
          VSpacing(2),
          MultiLineEdit(
            Id(:file),
            Opt(:hstretch, :vstretch),
            # multiline edit header
            _("Fi&le Contents")
          ),
          VSpacing(2)
        ),
        HSpacing(2)
      )

      # dialog caption
      caption = _("Expert Manual Configuration")
      help = getExpertManualHelp

      exits = [:back, :next, :abort, :ok, :apply, :accept]

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )

      Wizard.RestoreBackButton
      Wizard.RestoreAbortButton

      filename = Ops.get_string(filenames, 0, "")
      filename = defaultv if defaultv != ""
      if Ops.greater_than(Builtins.size(files), 1)
        UI.ChangeWidget(Id(:filename), :Value, filename)
      end
      UI.ChangeWidget(Id(:file), :Value, Ops.get(files, filename, ""))

      ret = nil
      while ret == nil || !Builtins.contains(exits, ret)
        ret = UI.UserInput
        if ret == :filename
          Ops.set(
            files,
            filename,
            Convert.to_string(UI.QueryWidget(Id(:file), :Value))
          )
          filename = Convert.to_string(UI.QueryWidget(Id(:filename), :Value))
          UI.ChangeWidget(Id(:file), :Value, Ops.get(files, filename, ""))
        end
        if ret == :next
          Ops.set(
            files,
            filename,
            Convert.to_string(UI.QueryWidget(Id(:file), :Value))
          )
          BootCommon.SetFilesContents(files)
          Bootloader.blRead(false, false)
          BootCommon.changed = true
          BootCommon.location_changed = true
        end
        ret = nil if !confirmAbortPopup if ret == :abort
      end
      Convert.to_symbol(ret)
    end
  end
end
