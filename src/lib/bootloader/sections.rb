require "yast"
require "yast2/execute"

Yast.import "Stage"

module Bootloader
  # Represents available sections and handling of default boot entry
  class Sections
    include Yast::Logger

    attr_reader :all

    # @param [CFA::Grub2::GrubCfg, nil] grub_cfg - loaded parsed grub cfg tree
    # or nil if not available yet
    def initialize(grub_cfg = nil)
      @data = grub_cfg ? grub_cfg.boot_entries : []
      @all = @data.map { |e| e[:title] }
    end

    # @return [String] name of default section
    def default
      return @default if @default

      return @default = "" if Yast::Stage.initial

      default_path = read_default

      @default = default_path ? path_to_title(default_path) : all.first
    end

    # Sets default section internally
    # @note to write it to system use #write later
    def default=(value)
      log.info "set new default to '#{value.inspect}'"

      # empty value mean no default specified
      raise "Unknown value #{value.inspect}" if !all.empty? && !all.include?(value) && !value.empty?

      @default = value
    end

    # writes default to system making it persistent
    def write
      return if default.empty?

      Yast::Execute.on_target("/usr/sbin/grub2-set-default", title_to_path(default))
    end

  private

    def read_default
      # Execute.on_target can return nil if call failed. It shows users error popup, but bootloader
      # can continue with empty default section
      saved = Yast::Execute.on_target("/usr/bin/grub2-editenv", "list", stdout: :capture) || ""
      saved_line = saved.lines.grep(/saved_entry=/).first

      saved_line ? saved_line[/saved_entry=(.*)$/, 1] : nil
    end

    def path_to_title(path)
      entry = @data.find { |e| e[:path] == path }

      entry ? entry[:title] : path
    end

    def title_to_path(title)
      entry = @data.find { |e| e[:title] == title }

      entry ? entry[:path] : title
    end
  end
end
