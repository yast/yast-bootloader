require "yast"

require "bootloader/bootloader_factory"

Yast.import "BootStorage"
Yast.import "Arch"

module Bootloader
  # Represents unsupported bootloader type error
  class UnsupportedBootloader < RuntimeError
    attr_reader :bootloader_name

    def initialize(bootloader_name)
      @bootloader_name = bootloader_name

      super "Unsupported bootloader '#{bootloader_name}'"
    end
  end

  # Converter between internal configuration model and autoyast serialization of configuration.
  class AutoyastConverter
    class << self
      include Yast::Logger

      def import(data)
        log.info "import data #{data.inspect}"

        bootloader = bootloader_from_data(data)
        return bootloader if bootloader.name == "none"
        # let it be empty if not defined to keep code simplier as effect is same
        data["global"] ||= {}

        import_grub2(data, bootloader)
        import_stage1(data, bootloader)
        import_default(data, bootloader.grub_default)
        import_device_map(data, bootloader)
        # TODO: import Initrd

        log.warn "autoyast profile contain sections which won't be processed" if data["sections"]

        bootloader
      end

      def export(config)
        log.info "exporting config #{config.inspect}"

        bootloader_type = config.name
        res = { "loader_type" => bootloader_type }

        return res if bootloader_type == "none"

        res["global"] = {}
        global = res["global"]
        export_grub2(global, config) if config.name == "grub2"
        export_default(global, config.grub_default)
        # Do not export device map as device name are very unpredictable and is used only as
        # work-around when automatic ones do not work for what-ever reasons ( it can really safe
        # your day in L3 )

        res
      end

    private

      def import_grub2(data, bootloader)
        return unless bootloader.name == "grub2"

        GRUB2_BOOLEAN_MAPPING.each do |key, method|
          val = data["global"][key]
          next unless val

          bootloader.public_send(:"#{method}=", val == "true")
        end
      end

      def import_default(data, default)
        DEFAULT_BOOLEAN_MAPPING.each do |key, method|
          val = data["global"][key]
          next unless val

          default.public_send(method).value = val == "true"
        end

        DEFAULT_STRING_MAPPING.each do |key, method|
          val = data["global"][key]
          next unless val

          default.public_send(:"#{method}=", SYMBOL_PARAM.include?(key) ? val.to_sym : val)
        end

        DEFAULT_KERNEL_PARAMS_MAPPING.each do |key, method|
          val = data["global"][key]
          next unless val

          default.public_send(method).replace(val)
        end

        import_timeout(data, default)
      end

      def import_timeout(data, default)
        return unless data["global"]["timeout"]

        if data["global"]["hiddenmenu"] == "true"
          default.timeout = "0"
          default.hidden_timeout = data["global"]["timeout"].to_s if data["global"]["timeout"]
        else
          default.timeout = data["global"]["timeout"].to_s if data["global"]["timeout"]
          default.hidden_timeout = "0"
        end
      end

      def import_device_map(data, bootloader)
        return unless bootloader.name == "grub2"
        return if !Yast::Arch.x86_64 && !Yast::Arch.i386

        dev_map = data["device_map"]
        return unless dev_map

        bootloader.device_map.clear_mapping
        dev_map.each do |entry|
          bootloader.device_map.add_mapping(entry["firmware"], entry["linux"])
        end
      end

      STAGE1_DEVICES_MAPPING = {
        "boot_root"     => :boot_devices,
        "boot_boot"     => :boot_devices,
        "boot_mbr"      => :mbr_devices,
        "boot_extended" => :boot_devices
      }.freeze
      def import_stage1(data, bootloader)
        return unless bootloader.name == "grub2"

        stage1 = bootloader.stage1

        if !data["global"]["generic_mbr"].nil?
          stage1.generic_mbr = data["global"]["generic_mbr"] == "true"
        end

        if !data["global"]["activate"].nil?
          stage1.activate = data["global"]["activate"] == "true"
        # old one from SLE9 ages, it uses boolean and not string
        elsif !data["activate"].nil?
          stage1.activate = data["activate"]
        end

        import_stage1_devices(data, stage1)
      end

      def import_stage1_devices(data, stage1)
        STAGE1_DEVICES_MAPPING.each do |key, method|
          if data["global"][key] == "true" || data["boot_#{key}"]
            stage1.public_send(method).each do |dev_name|
              stage1.add_udev_device(dev_name)
            end
          end
        end

        import_custom_devices(data, stage1)
      end

      def import_custom_devices(data, stage1)
        # SLE9 way to define boot device
        if data["loader_device"] && !data["loader_device"].empty?
          stage1.add_udev_device(data["loader_device"])
        end

        return if !data["global"]["boot_custom"] || data["global"]["boot_custom"].empty?

        data["global"]["boot_custom"].split(",").each do |dev|
          stage1.add_udev_device(dev.strip)
        end
      end

      def bootloader_from_data(data)
        loader_type = data["loader_type"] || "default"
        allowed = BootloaderFactory::SUPPORTED_BOOTLOADERS + ["default"]

        raise UnsupportedBootloader, loader_type if !allowed.include?(loader_type)

        # ensure it is clear bootloader config
        BootloaderFactory.clear_cache

        if loader_type == "default"
          BootloaderFactory.proposed
        else
          BootloaderFactory.bootloader_by_name(loader_type)
        end
      end

      # only for grub2, not for others
      GRUB2_BOOLEAN_MAPPING = {
        "trusted_grub" => :trusted_boot
      }.freeze
      def export_grub2(res, bootloader)
        GRUB2_BOOLEAN_MAPPING.each do |key, method|
          val = bootloader.public_send(method)
          res[key] = val ? "true" : "false" unless val.nil?
        end
      end

      DEFAULT_BOOLEAN_MAPPING = {
        "os_prober" => :os_prober
      }.freeze

      DEFAULT_STRING_MAPPING = {
        "gfxmode"  => :gfxmode,
        "serial"   => :serial_console,
        "terminal" => :terminal
      }.freeze

      DEFAULT_KERNEL_PARAMS_MAPPING = {
        "append"            => :kernel_params,
        "xen_append"        => :xen_kernel_params,
        "xen_kernel_append" => :xen_hypervisor_params
      }.freeze

      SYMBOL_PARAM = [
        "terminal"
      ].freeze
      def export_default(res, default)
        DEFAULT_BOOLEAN_MAPPING.each do |key, method|
          val = default.public_send(method)
          res[key] = val.enabled? ? "true" : "false" if val.defined?
        end

        DEFAULT_STRING_MAPPING.each do |key, method|
          val = default.public_send(method)
          res[key] = val.to_s if val
        end

        DEFAULT_KERNEL_PARAMS_MAPPING.each do |key, method|
          val = default.public_send(method)
          res[key] = val.serialize unless val.empty?
        end

        export_timeout(res, default)
      end

      def export_timeout(res, default)
        if default.hidden_timeout.to_s.to_i > 0
          res["hiddenmenu"] = "true"
          res["timeout"] = default.hidden_timeout.to_s.to_i
        else
          res["hiddenmenu"] = "false"
          res["timeout"] = default.timeout.to_s.to_i
        end
      end
    end
  end
end
