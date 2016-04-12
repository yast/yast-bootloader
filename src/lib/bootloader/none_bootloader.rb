require "yast"

require "bootloader/bootloader_base"

Yast.import "HTML"

module Bootloader
  # Represents when bootloader want user manage itself
  class NoneBootloader < BootloaderBase
    include Yast::I18n
    def summary
      textdomain "bootloader"

      [Yast::HTML.Colorize(
        _("Do not install any boot loader"),
        "red"
      )]
    end

    def name
      "none"
    end
  end
end
