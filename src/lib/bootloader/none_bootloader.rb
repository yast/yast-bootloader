require "yast"

Yast.import "HTML"

module Bootloader
  # Represents when bootloader want user manage itself
  class NoneBootloader < BootloaderBase
    def summary
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
