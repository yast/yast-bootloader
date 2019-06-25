# frozen_string_literal: true

require "yast"

Yast.import "Bootloader"
Yast.import "Wizard"

module Bootloader
  # Dialog providing visual feedback during writing configuration
  class WriteDialog
    include Yast::I18n

    # Write settings dialog
    #
    # @return [Symbol] :abort if aborted
    #                  :next otherwise
    def run
      Yast::Wizard.RestoreHelp(help_text)

      Yast::Bootloader.Write ? :next : :abort
    end

  private

    def help_text
      textdomain "bootloader"

      _(
        "<P><B><BIG>Saving Boot Loader Configuration</BIG></B><BR>\nPlease wait...<br></p>"
      )
    end
  end
end
