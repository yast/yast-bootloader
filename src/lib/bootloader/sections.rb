require "yast"
require "yast2/execute"

module Bootloader
  # Represents available sections and handling of default boot entry
  class Sections
    # @param [CFA::Grub2::GrubCfg] grub_cfg - loaded parsed grub cfg tree
    def initialize(grub_cfg)
      @data = grub_cfg.sections
    end

    # Gets all available sections
    def all
      @data
    end

    # @return [String] name of default section
    def default
      return @default if @default

      saved = Yast::Execute.on_target("/usr/bin/grub2-editenv", "list", stdout: :capture)
      saved_line = saved.lines.grep(/saved_entry=/).first

      saved_line ? saved_line[/saved_entry=(\S*)\s\n/, 1] : @data.first
    end

    # Sets default section internally
    # @note to write it to system use #write later
    def default=(value)
      raise "Unknown value #{value.inspect}" unless @data.include?(value)
      @default = value
    end

    # writes default to system making it persistent
    def write
      Yast::Execute.on_target("/usr/sbin/grub2-set-default", default)
    end
  end
end
