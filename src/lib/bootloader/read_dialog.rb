require "yast"

Yast.import "Bootloader"
Yast.import "Wizard"

module Bootloader
  # Dialog for graphical indication that bootloader configuration is read
  class ReadDialog
    include Yast::I18n

    def run
      Yast::Wizard.RestoreHelp(help_text)
      ret = Yast::Bootloader.Read
      ret ? :next : :abort
    end

  private

    def help_text
      textdomain "bootloader"

      _(
        "<P><BIG><B>Boot Loader Configuration Tool</B></BIG><BR>\n" \
          "Reading current configuration...</P>"
      )
    end
  end
end
