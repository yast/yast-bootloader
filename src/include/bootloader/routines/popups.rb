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
      loop do
        button = Convert.to_symbol(UI.UserInput)
        break if button == :yes || button == :no
      end

      UI.CloseDialog

      button == :yes
    end
  end
end
