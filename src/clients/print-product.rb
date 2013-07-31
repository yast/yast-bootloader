# encoding: utf-8

# File:
#      clients/print-product.ycp
#
# Module:
#      Print product name
#
# Summary:
#      Prints the product name -- used by update-bootloader
#
# Authors:
#      Stefan Fent <sf@suse.de>
#      Olaf Dabrunz <od@suse.de>
#
# $Id$
#
module Yast
  class PrintProductClient < Client
    def main
      Yast.import "Product"
      Yast.import "CommandLine"
      Yast.import "Mode"

      @name = ""

      # activate command line mode
      Mode.SetUI("commandline")
      # get loader type
      @loader = Convert.to_string(
        SCR.Read(path(".sysconfig.bootloader.LOADER_TYPE"))
      )
      if @loader == "grub"
        @name = Product.name
      else
        @name = Product.short_name
      end
      CommandLine.Print(@name)

      nil
    end
  end
end

Yast::PrintProductClient.new.main
