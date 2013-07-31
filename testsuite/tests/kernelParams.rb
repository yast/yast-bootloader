# encoding: utf-8

# File:
#  kernelParams.ycp
#
# Module:
#  Bootloader configurator
#
# Summary:
#  Bootloader kernel parameters handling testsuites
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  class KernelParamsClient < Client
    def main
      # testedfiles: BootCommon.ycp bootloader/routines/lilolike.ycp bootloader/routines/misc.ycp
      Yast.include self, "testsuite.rb"

      @READ_I = {
        "target"    => { "size" => -1, "tmpdir" => "/tmp/", "yast2" => nil },
        "probe"     => {
          "architecture" => "i386",
          "has_apm"      => true,
          "has_pcmcia"   => false,
          "has_smp"      => false,
          "system"       => [],
          "memory"       => [],
          "cpu"          => [],
          "cdrom"        => { "manual" => [] },
          "floppy"       => { "manual" => [] },
          "is_uml"       => false
        },
        "sysconfig" => {
          "console"  => {
            "CONSOLE_FONT"       => "",
            "CONSOLE_SCREENMAP"  => "",
            "CONSOLE_UNICODEMAP" => "",
            "CONSOLE_MAGIC"      => "",
            "CONSOLE_ENCODING"   => ""
          },
          "language" => { "RC_LANG" => "", "DEFAULT_LANGUAGE" => "" }
        },
        "etc"       => { "install_inf" => { "Cmdline" => "", "Cdrom" => "" } },
        "proc"      => {
          "cpuinfo" => { "value" => { "0" => { "flags" => "" } } }
        },
        "product"   => {
          "features" => {
            "USE_DESKTOP_SCHEDULER"           => "0",
            "ENABLE_AUTOLOGIN"                => "0",
            "EVMS_CONFIG"                     => "0",
            "IO_SCHEDULER"                    => "cfg",
            "UI_MODE"                         => "expert",
            "INCOMPLETE_TRANSLATION_TRESHOLD" => "95"
          }
        }
      }
      @WRITE_I = {}
      @EXEC_I = { "target" => { "bash_output" => {} } }

      TESTSUITE_INIT([@READ_I, @WRITE_I, @EXEC_I], 0)
      Yast.import "BootCommon"

      @line = ""

      DUMP("======================================")

      @line = "(hd0,0)/vmlinuz root=/dev/hda3 vga=123 noapic hdc=ide-scsi"

      TEST(lambda { BootCommon.getKernelParamFromLine(@line, "vga") }, [], 0)
      TEST(lambda { BootCommon.getKernelParamFromLine(@line, "root") }, [], 0)
      TEST(lambda { BootCommon.getKernelParamFromLine(@line, "noapic") }, [], 0)
      TEST(lambda { BootCommon.getKernelParamFromLine(@line, "hdc") }, [], 0)
      TEST(lambda { BootCommon.getKernelParamFromLine(@line, "nosmp") }, [], 0)

      DUMP("======================================")

      @line = "root=/dev/hda3 vga=123 noapic hdc=ide-scsi"

      TEST(lambda { BootCommon.getKernelParamFromLine(@line, "vga") }, [], 0)
      TEST(lambda { BootCommon.getKernelParamFromLine(@line, "root") }, [], 0)
      TEST(lambda { BootCommon.getKernelParamFromLine(@line, "noapic") }, [], 0)
      TEST(lambda { BootCommon.getKernelParamFromLine(@line, "hdc") }, [], 0)
      TEST(lambda { BootCommon.getKernelParamFromLine(@line, "nosmp") }, [], 0)

      DUMP("======================================")

      @line = "(hd0,0)/vmlinuz root=/dev/hda3 vga=123 noapic hdc=ide-scsi"

      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "321") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "false") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "true") }, [], 0)

      TEST(lambda { BootCommon.setKernelParamToLine(@line, "noapic", "321") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "noapic", "false") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "noapic", "true") }, [], 0)

      TEST(lambda { BootCommon.setKernelParamToLine(@line, "nosmp", "321") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "nosmp", "false") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "nosmp", "true") }, [], 0)

      DUMP("======================================")

      @line = "root=/dev/hda3 vga=123 noapic hdc=ide-scsi"

      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "321") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "false") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "true") }, [], 0)

      TEST(lambda { BootCommon.setKernelParamToLine(@line, "noapic", "321") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "noapic", "false") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "noapic", "true") }, [], 0)

      TEST(lambda { BootCommon.setKernelParamToLine(@line, "nosmp", "321") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "nosmp", "false") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "nosmp", "true") }, [], 0)

      DUMP("======================================")

      @line = Ops.add(@line, " vga=567")

      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "321") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "false") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "true") }, [], 0)

      DUMP("======================================")

      @line = Ops.add(@line, " noapic")

      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "321") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "false") }, [], 0)
      TEST(lambda { BootCommon.setKernelParamToLine(@line, "vga", "true") }, [], 0)

      DUMP("======================================")

      nil
    end
  end
end

Yast::KernelParamsClient.new.main
