require "yast"
require "yast2/execute"

module Bootloader
  # Represents available sections and handling of default boot entry
  class Sections
    include Yast::Logger

    # @param [CFA::Grub2::GrubCfg, nil] grub_cfg - loaded parsed grub cfg tree
    # or nil if not available yet
    def initialize(grub_cfg = nil)
      @data = grub_cfg ? grub_cfg.sections : []
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
      log.info "set new default to '#{value.inspect}'"

      # empty value mean no default specified
      raise "Unknown value #{value.inspect}" if !@data.include?(value) && !value.empty?

      @default = value
    end

    # writes default to system making it persistent
    def write
      return if default.empty?
      Yast::Execute.on_target("/usr/sbin/grub2-set-default", default)
    end
  end
end
