require "yast"
require "yast2/execute"

module Bootloader
  class Sections
    def initialize(grub_cfg)
      @data = grub_cfg.sections
    end

    def all
      @data
    end

    def default
      return @default if @default

      saved = Yast::Execute.on_target("/usr/bin/grub2-editenv", "list", stdout: :capture)
      saved_line = saved.lines.grep(/saved_entry=/).first

      saved_line || @data.first
    end

    def default=(value)
      raise "Unknown value #{value.inspect}" unless @data.include?(value)
      @default = value
    end

    def write
      Yast::Execute.on_target("/usr/sbin/grub2-set-default", @default)
    end
  end
end
