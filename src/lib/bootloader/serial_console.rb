require "yast"

Yast.import "Arch"

module Bootloader
  class SerialConsole
    PARITY_MAP = {
      "n" => "no",
      "o" => "odd",
      "e" => "even"
    }
    SPEED_DEFAULT = 9600
    PARITY_DEFAULT = "no"
    WORD_DEFAULT = ""

    def self.load_from_kernel_args(kernel_params)
      console_parameter = kernel_params.parameter("console")
      return nil unless console_parameter

      console_parameter = [console_parameter] unless console_parameter.is_a? ::Array
      serial_console = console_parameter.find { |p| p =~ /ttyS/ || p =~ /ttyAMA/ }
      return nil unless serial_console

      console_regexp = /(ttyS|ttyAMA)[[:alpha:]]+([[:digit:]]*),?([[:digit:]]*)([noe]*)([[:digit:]]*)/
      unit = serial_console[console_regexp, 2]
      return nil if unit.empty

      speed = serial_console[console_regexp, 3]
      speed = SPEED_DEFAULT if speed.empty?
      parity = serial_console[console_regexp, 4]
      parity = PARITY_DEFAULT if parity.empty?
      parity = PARITY_MAP[parity]
      word = serial_console[console_regexp, 5]

      new(unit, speed, parity, word)
    end

    def self.load_from_console_args(console_args)
      unit = console_args[/--unit=(\S+)/, 1]
      return nil unless unit

      speed = console_args[/--speed=(\S+)/, 1] || SPEED_DEFAULT
      parity = console_args[/--parity=(\S+)/, 1] || PARITY_DEFAULT
      word = console_args[/--word=(\S+)/, 1] || WORD_DEFAULT

      new(unit, speed, parity, word)
    end

    def initialize(unit, speed=SPEED_DEFAULT, parity=PARITY_DEFAULT,
        word=WORD_DEFAULT)
      @unit = unit
      @speed = speed
      @parity = parity
      @word = word
    end

    def kernel_args
      serial_console = Yast::Arch.aarch64 ? "ttyS" : "ttyAMA"

      "#{serial_console}#{@unit},#{@speed}#{@parity[0]}#{@word}"
    end

    def console_args
      res = "serial --unit=#{@unit} --speed=#{@speed} --parity=#{@parity}"
      res << " --word=#{@word}" unless @word.empty?

      res
    end
  end
end
