require "yast"

require "bootloader/bootloader_factory"

Yast.import "BootStorage"

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
        bootloader = bootloader_from_data(data)
        return bootloader if bootloader.name == "none"

        import_stage1(data, bootloader)
        import_default(data, bootloader)
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
        export_stage1(global, config.stage1) if config.respond_to?(:stage1)
        export_default(global, config.grub_default)

        res
      end

    private

      def import_default(data, bootloader)
        DEFAULT_BOOLEAN_MAPPING.each do |key, method|
          next unless data["global"][key]

          bootloader.grub_default.public_send(method).value = data["global"][key] == "true"
        end

        DEFAULT_STRING_MAPPING.each do |key, method|
          next unless data["global"][key]

          bootloader.grub_default.public_send(:"#{method}=", data["global"][key])
        end

        DEFAULT_KERNEL_PARAMS_MAPPING.each do |key, method|
          next unless data["global"][key]

          bootloader.grub_default.public_send(method).replace(data["global"][key])
        end

        import_timeout(data, bootloader)
      end

      def import_timeout(data, bootloader)
        return unless data["global"]["timeout"]

        if data["global"]["hiddenmenu"] == "true"
          bootloader.grub_default.timeout = "0"
          bootloader.grub_default.hidden_timeout = data["global"]["timeout"]
        else
          bootloader.grub_default.timeout = data["global"]["timeout"]
          bootloader.grub_default.hidden_timeout = "0"
        end
      end

      STAGE1_DEVICES_MAPPING = {
        "boot_root"     => :RootPartitionDevice,
        "boot_boot"     => :BootPartitionDevice,
        "boot_mbr"      => :mbr_disk,
        "boot_extended" => :ExtendedPartitionDevice
      }
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
        # extended partion maybe do not exists, so report it to user
        if (data["global"]["boot_extended"] == "true" ||
            data["location"] == "extended") &&
            Yast::BootStorage.ExtendedPartitionDevice.nil?
          raise "boot_extended used in autoyast profile, but there is no extended partition"
        end

        STAGE1_DEVICES_MAPPING.each do |key, device|
          if data["global"][key] == "true" || data["boot_#{key}"]
            stage1.add_udev_device(Yast::BootStorage.public_send(device))
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

      STAGE1_MAPPING = {
        "activate"      => :activate?,
        "generic_mbr"   => :generic_mbr?,
        "boot_root"     => :root_partition?,
        "boot_boot"     => :boot_partition?,
        "boot_mbr"      => :mbr?,
        "boot_extended" => :extended_partition?
      }
      def export_stage1(res, stage1)
        STAGE1_MAPPING.each do |key, method|
          res[key] = stage1.public_send(method) ? "true" : "false"
        end

        res["boot_custom"] = stage1.custom_devices.join(",") unless stage1.custom_devices.empty?
      end

      DEFAULT_BOOLEAN_MAPPING = {
        "os_prober" => :os_prober
      }

      DEFAULT_STRING_MAPPING = {
        "gfxmode"  => :gfxmode,
        "serial"   => :serial_console,
        "terminal" => :terminal
      }

      DEFAULT_KERNEL_PARAMS_MAPPING = {
        "append"            => :kernel_params,
        "xen_append"        => :xen_kernel_params,
        "xen_kernel_append" => :xen_hypervisor_params
      }
      def export_default(res, default)
        DEFAULT_BOOLEAN_MAPPING.each do |key, method|
          val = default.public_send(method)
          res[key] = val.enabled? ? "true" : "false" if val.defined?
        end

        DEFAULT_STRING_MAPPING.each do |key, method|
          val = default.public_send(method)
          res[key] = val if val
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
