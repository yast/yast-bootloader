# frozen_string_literal: true

require "json"
require "yast"
require "yast2/execute"
require "bootloader/bls"

Yast.import "Misc"

module Bootloader
  # Represents available sections and handling of default BLS boot entry
  class BlsSections
    include Yast::Logger

    # @return [Array<String>] list of all available boot titles
    # or an empty array
    attr_reader :all

    def initialize
      @all = []
      @default = ""
    end

    # @return [String] title of default boot section.
    def default
      return "" unless @data

      entry = @data.find { |d| d["id"] == @default }
      entry ? entry["title"] : ""
    end

    # Sets default section internally.
    # @param [String] value of new boot title to boot
    # @note to write it to system use #write later
    def default=(value)
      return unless @data

      entry = @data.find { |d| d["title"] == value }
      if entry
        @default = entry["id"]
        log.info "set new default to '#{value.inspect}' --> '#{@default}'"
      else
        log.warn "Invalid value '#{value}'"
        @default = ""
      end
    end

    # writes default to system making it persistent
    def write
      return if @default.empty?

      set = @data.find { |d| d["title"] == @default }
      Bls.write_default_menu(set["id"]) if set
    end

    def read
      @data = read_entries
      @all = @data.map { |e| e["title"] if e["type"] == "type1" }.compact
      file = Bls.default_menu.strip
      set = @data.find { |d| d["id"] == file }
      set ||= @data.first
      @default = set["title"] if set
    end

  private

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
