# frozen_string_literal: true

require "json"
require "yast"
require "yast2/execute"

Yast.import "Misc"

module Bootloader
  # Represents available sections and handling of default BLS boot entry
  class BlsSections
    include Yast::Logger

    # @return [Array<String>] list of all available boot titles
    # or an empty array
    attr_reader :all

    # @return [String] title of default boot section.
    attr_reader :default

    def initialize
      @all = []
      @default = ""
    end

    # Sets default section internally.
    # @param [String] value of new boot title to boot
    # @note to write it to system use #write later
    def default=(value)
      log.info "set new default to '#{value.inspect}'"

      # empty value mean no default specified
      if !all.empty? && !all.include?(value) && !value.empty?
        log.warn "Invalid value #{value} trying to set as default. Fallback to default"
        value = ""
      end

      @default = value
    end

    # writes default to system making it persistent
    def write
      return if @default.empty?

      write_default
    end

    def read
      @data = read_entries
      @all = @data.map { |e| e["title"] }
      @default = read_default
    end

  private

    OS_RELEASE_PATH = "/etc/os-release"

    def grubenv_path
      str = Yast::Misc.CustomSysconfigRead("ID_LIKE", "openSUSE",
        OS_RELEASE_PATH)
      os = str.split.first
      File.join("/boot/efi/EFI/", os, "/grubenv")
    end

    # @return [String] return default boot as string or "" if not set
    # or something goes wrong
    def read_default
      Yast::Misc.CustomSysconfigRead("default", "",
        grubenv_path)
    end

    # write default entry
    def write_default
      ret = Yast::Execute.on_target("/usr/bin/sdbootutil",
        "set-default", @default,
        allowed_exitstatus: [0, 1])

      return unless ret != 0

      # fallback directly over grub2-editenv
      Yast::Execute.on_target("/usr/bin/grub2-editenv", grubenv_path,
        "set", "default=" + @default)
    end

    # @return [Array] return array of entries or []
    def read_entries
      output = Yast::Execute.on_target(
        "/usr/bin/bootctl", "--json=short", "list", stdout: :capture
      )
      return [] if output.nil?

      JSON.parse(output)
    end
  end
end
