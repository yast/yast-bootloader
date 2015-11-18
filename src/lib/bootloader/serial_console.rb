require "yast"

Yast.import "Arch"

module Bootloader
  # Represents parameters for console. Its main intention is easy parsing serial
  # console parameters parameters for grub or kernel and generate it to keep it
  # in sync.
  class SerialConsole
    PARITY_MAP = {
      "n" => "no",
      "o" => "odd",
      "e" => "even"
    }
    SPEED_DEFAULT = 9600
    PARITY_DEFAULT = "no"
    WORD_DEFAULT = ""

    # REGEXP that separate usefull parts of kernel parameter for serial console
    # matching groups are:
    #
    # 1. serial console device
    # 2. console unit
    # 3. speed of serial console ( baud rate )
    # 4. parity of serial console ( just first letter )
    # 5. word length for serial console
    #
    # For details see https://en.wikipedia.org/wiki/Serial_port
    # @example serial console param ( on kernel cmdline "console=<example>" )
    #    "ttyS0,9600n8"
    # @example also partial specification works
    #    "ttyAMA1"
    KERNEL_PARAM_REGEXP = /(ttyS|ttyAMA)([[:digit:]]*),?([[:digit:]]*)([noe]*)([[:digit:]]*)/

    # Loads serial console configuration from parameters passed to kernel
    # @param [ConfigFiles::Grub2::Default::KernelParams] kernel_params to read
    # @return [Bootloader::SerialConsole,nil] returns nil if none found,
    #   otherwise instance of SerialConsole
    def self.load_from_kernel_args(kernel_params)
      console_parameter = kernel_params.parameter("console")
      return nil unless console_parameter

      console_parameter = Array(console_parameter)
      serial_console = console_parameter.find { |p| p =~ /ttyS/ || p =~ /ttyAMA/ }
      return nil unless serial_console

      unit = serial_console[KERNEL_PARAM_REGEXP, 2]
      return nil if unit.empty?

      speed = serial_console[KERNEL_PARAM_REGEXP, 3]
      speed = SPEED_DEFAULT if speed.empty?
      parity = serial_console[KERNEL_PARAM_REGEXP, 4]
      parity = PARITY_DEFAULT[0] if parity.empty?
      parity = PARITY_MAP[parity]
      word = serial_console[KERNEL_PARAM_REGEXP, 5]

      new(unit, speed, parity, word)
    end

    # Loads serial console configuration from parameters passed to grub
    # @param [String] console_args string passed to grub as configuration
    # @return [Bootloader::SerialConsole,nil] returns nil if none found,
    #   otherwise instance of SerialConsole
    # @example
    #   console_arg = "serial --speed=38400 --unit=0 --word=8 --parity=no --stop=1"
    #   SerialConsole.load_from_console_args(console_arg)
    def self.load_from_console_args(console_args)
      unit = console_args[/--unit=(\S+)/, 1]
      return nil unless unit

      speed = console_args[/--speed=(\S+)/, 1] || SPEED_DEFAULT
      parity = console_args[/--parity=(\S+)/, 1] || PARITY_DEFAULT
      word = console_args[/--word=(\S+)/, 1] || WORD_DEFAULT

      new(unit, speed, parity, word)
    end

    def initialize(unit, speed = SPEED_DEFAULT, parity = PARITY_DEFAULT,
        word = WORD_DEFAULT)
      @unit = unit
      @speed = speed
      @parity = parity
      @word = word
    end

    # generates kernel argument usable for passing it with `console=<result>`
    def kernel_args
      serial_console = Yast::Arch.aarch64 ? "ttyAMA" : "ttyS"

      "#{serial_console}#{@unit},#{@speed}#{@parity[0]}#{@word}"
    end

    # generates serial command for grub2
    def console_args
      res = "serial --unit=#{@unit} --speed=#{@speed} --parity=#{@parity}"
      res << " --word=#{@word}" unless @word.empty?

      res
    end
  end
end
