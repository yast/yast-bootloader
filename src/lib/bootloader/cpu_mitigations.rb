require "yast"

require "cfa/matcher"
require "cfa/placer"

module Bootloader
  class CpuMitigations
    include Yast::I18n
    extend Yast::I18n
    KERNEL_MAPPING = {
      nosmt:  "auto,nosmt",
      auto:   "auto",
      off:    "off",
      manual: nil
    }.freeze

    HUMAN_MAPPING = {
        nosmt: N_("Auto + No SMT"),
        auto: N_("Auto"),
        off: N_("Off"),
        manual: N_("Manually")
    }


    attr_reader :value

    def initialize(value)
      textdomain "bootloader"

      @value = value
    end

    ALL = KERNEL_MAPPING.keys.map { |k| CpuMitigations.new(k) }
    DEFAULT = CpuMitigations.new(:auto)

    def self.from_kernel_params(kernel_params)
      param = kernel_params.parameter("mitigations")
      param = nil if param == false
      reverse_mapping = KERNEL_MAPPING.invert
      raise "Unknown mitigations value #{param.inspect}" if !reverse_mapping.key?(param)

      new(reverse_mapping[param])
    end

    def self.from_string(string)
      raise "Unknown mitigations value #{string.inspect}" if KERNEL_MAPPING.key?(string.to_sym)

      new(string.to_sym)
    end

    def to_human_string
      _(HUMAN_MAPPING[value])
    end

    def kernel_value
      KERNEL_MAPPING[value] or raise "Invalid value #{value.inspect}"
    end

    def modify_kernel_params(kernel_params)
      matcher = CFA::Matcher.new(key: "mitigations")

      if value == :manual
        kernel_params.remove_parameter(matcher)
      else
        placer = CFA::ReplacePlacer.new(matcher)
        kernel_params.add_parameter("mitigations", text, placer)
      end

    end
  end
end
