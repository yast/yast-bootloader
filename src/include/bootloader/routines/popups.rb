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
  module BootloaderRoutinesPopupsInclude
    def initialize_bootloader_routines_popups(include_target)
      textdomain "bootloader"

      Yast.import "Encoding"
      Yast.import "Label"
      Yast.import "Misc"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "String"
    end

    # Inform about not available functionality when no loader selected
    def NoLoaderAvailable
      # popup message
      Popup.Message(
        _(
          "This function is not available if the boot\nloader is not specified."
        )
      )

      nil
    end

    # Display question
    # @return [Boolean] true if answered yes
    def confirmAbortPopup
      # yes-no popup question
      Popup.YesNo(
        _(
          "Really leave the boot loader configuration without saving?\nAll changes will be lost.\n"
        )
      )
    end

    # Display error
    def emptyPasswdErrorPopup
      # error popup
      Report.Error(_("The password must not be empty."))

      nil
    end

    # Display error
    def passwdMissmatchPopup
      # error popup
      Report.Error(
        _(
          "'Password' and 'Retype password'\ndo not match. Retype the password."
        )
      )

      nil
    end

    # Display popup about change of section
    # @param [String] sect_name string section name
    def displayDiskChangePopup(sect_name)
      # message popup, %1 is sectino label
      Popup.Message(
        Builtins.sformat(
          _("The disk settings have changed.\nCheck section %1 settings.\n"),
          sect_name
        )
      )

      nil
    end

    # Display popup
    def displayFilesEditedPopup
      # message popup
      Popup.Message(
        _(
          "The disk settings have changed and you edited boot loader\nconfiguration files manually. Check the boot loader settings.\n"
        )
      )

      nil
    end

    # Ask for change of bootloader location because of device unavailability
    # @param [String] reason text stating why the location should be re-proposed
    # @return [Boolean] yes if shall be reset
    def askLocationResetPopup(reason)
      Popup.YesNo(
        # Confirmation box with yes-no popup. %1 is reason why we need to set
        # default location. It is translated on caller side and it is complete
        # sentence.
        Builtins.sformat(_("%1Set default boot loader location?\n"), reason)
      )
    end

    # Show the popup before saving to floppy, handle actions
    # @return true on success
    def saveToFLoppyPopup
      retval = true
      format = false
      fs = :no
      items = [
        # combobox item
        Item(Id(:no), _("Do Not Create a File System")),
        # combobox item
        Item(Id(:ext2), _("Create an ext2 File System"))
      ]
      if SCR.Read(path(".target.size"), "/sbin/mkfs.msdos") != -1
        # combobox item
        items = Builtins.add(
          items,
          Item(Id(:fat), _("Create a FAT File System"))
        )
      end
      contents = VBox(
        # label
        Label(
          _(
            "The boot loader boot sector will be written\n" +
              "to a floppy disk. Insert a floppy disk\n" +
              "and confirm with OK.\n"
          )
        ),
        VSpacing(1),
        # checkbox
        Left(CheckBox(Id(:format), _("&Low Level Format"), false)),
        VSpacing(1),
        # combobox
        Left(ComboBox(Id(:fs), _("&Create File System"), items)),
        VSpacing(1),
        PushButton(Id(:ok), Label.OKButton)
      )
      UI.OpenDialog(contents)
      ret = nil
      while ret != :ok
        ret = UI.UserInput
      end
      if ret == :ok
        format = Convert.to_boolean(UI.QueryWidget(Id(:format), :Value))
        fs = Convert.to_symbol(UI.QueryWidget(Id(:fs), :Value))
      end
      UI.CloseDialog
      # FIXME: loader_device cannot be used for grub anymore; but this
      # function should not be used anymore anyway, because BootFloppy has
      # been disabled.
      dev = BootCommon.loader_device
      if format
        tmpretval = true
        Builtins.y2milestone("Low level formating floppy")
        while true
          tmpretval = 0 ==
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat("/usr/bin/fdformat %1", dev)
            )
          break if tmpretval
          # yes-no popup
          break if !Popup.YesNo(_("Low level format failed. Try again?"))
        end
        retval = retval && tmpretval
      end
      if fs == :ext2
        Builtins.y2milestone("Creating ext2 on floppy")
        tmpretval = 0 ==
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("/sbin/mkfs.ext2 %1", dev)
          )
        if !tmpretval
          # error report
          Report.Error(_("Creating file system failed."))
        end
        retval = retval && tmpretval
      elsif fs == :fat
        Builtins.y2milestone("Creating msdosfs on floppy")
        tmpretval = 0 ==
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("/sbin/mkfs.msdos %1", dev)
          )
        if !tmpretval
          # error report
          Report.Error(_("Creating file system failed."))
        end
        retval = retval && tmpretval
      end
      retval
    end

    # Display error
    def usedNameErrorPopup
      # error popup
      Report.Error(
        _("The name selected is already used.\nUse a different one.\n")
      )

      nil
    end

    # Display error
    # @return true if shall retry
    def writeErrorPopup
      # yes-no popup
      Popup.YesNo(
        _(
          "An error occurred during boot loader\ninstallation. Retry boot loader configuration?\n"
        )
      )
    end

    # Display error popup with log
    # @param [String] header string error header
    # @param [String] log string logfile contents
    def errorWithLogPopup(header, log)
      if log == nil
        # FIXME too generic, but was already translated
        log = _("Unable to install the boot loader.")
      end
      text = RichText(Opt(:plainText), log)
      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          HSpacing(75),
          Heading(header),
          # heading
          HBox(
            VSpacing(14), # e.g. `Richtext()
            text
          ),
          PushButton(Id(:ok_help), Opt(:default), Label.OKButton)
        )
      )

      UI.SetFocus(Id(:ok_help))
      r = UI.UserInput
      UI.CloseDialog

      nil
    end

    # Display popup - confirmation befopre restoring MBR
    # @param [String] device string device to restore to
    # @return [Boolean] true of MBR restore confirmed
    def restoreMBRPopup(device)
      stat = Convert.to_map(SCR.Read(path(".target.stat"), "/boot/backup_mbr"))
      ctime = Ops.get_integer(stat, "ctime", 0)
      command = Builtins.sformat(
        "date --date='1970-01-01 00:00:00 %1 seconds'",
        ctime
      )
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      c_time = Ops.get_string(out, "stdout", "")
      c_time = String.FirstChunk(c_time, "\n")
      c_time = Convert.to_string(UI.Recode(Encoding.console, "UTF-8", c_time))

      # warning popup. %1 is device name, %2 is date/time in form of
      # 'date' command output
      msg = Builtins.sformat(
        _(
          "Warning!\n" +
            "\n" +
            "Current MBR of %1 will now be rewritten with MBR\n" +
            "saved at %2.\n" +
            "\n" +
            "Only the booting code in the MBR will be rewritten.\n" +
            "The partition table remains unchanged.\n" +
            "\n" +
            "Continue?\n"
        ),
        device,
        c_time
      )

      dialog = HBox(
        HSpacing(1),
        VBox(
          VSpacing(0.2),
          Label(msg),
          HBox(
            # PushButton
            PushButton(Id(:yes), _("&Yes, Rewrite")),
            HStretch(),
            PushButton(Id(:no), Opt(:default), Label.NoButton)
          ),
          VSpacing(0.2)
        ),
        HSpacing(1)
      )

      UI.OpenDialog(Opt(:decorated, :warncolor), dialog)

      button = nil
      begin
        button = Convert.to_symbol(UI.UserInput)
      end until button == :yes || button == :no

      UI.CloseDialog

      button == :yes
    end
  end
end
