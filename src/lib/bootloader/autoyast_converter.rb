# frozen_string_literal: true

require "yast"

require "bootloader/bootloader_factory"
require "bootloader/cpu_mitigations"

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
  # rubocop:disable Metrics/ClassLength converting autoyast profiles is just a lot of data
  class AutoyastConverter
    class << self
      include Yast::Logger

      # @param data [AutoinstProfile::BootloaderSection] Bootloader section from a profile
      def import(data)
        log.info "import data #{data.inspect}"

        bootloader = bootloader_from_data(data)
        return bootloader if bootloader.name == "none"

        case bootloader.name
        when "grub2", "grub2-efi"
          import_grub2(data, bootloader)
          import_grub2efi(data, bootloader)
          import_stage1(data, bootloader)
          import_default(data, bootloader.grub_default)
          import_device_map(data, bootloader)
          import_password(data, bootloader)
          # always nil pmbr as autoyast does not support it yet,
          # so use nil to always use proposed value (bsc#1081967)
          bootloader.pmbr_action = nil
          cpu_mitigations = data.global.cpu_mitigations
          if cpu_mitigations
            bootloader.cpu_mitigations = CpuMitigations.from_string(cpu_mitigations)
          end
        when "systemd-boot"
          bootloader.menu_timeout = data.global.timeout
          bootloader.secure_boot = data.global.secure_boot
        else
          raise UnsupportedBootloader, bootloader.name
        end
        # TODO: import Initrd
        log.warn "autoyast profile contain sections which won't be processed" if data.sections

        bootloader
      end

      # FIXME: use AutoinstProfile classes
      def export(config)
        log.info "exporting config #{config.inspect}"

        bootloader_type = config.name
        res = { "loader_type" => bootloader_type }

        return res if bootloader_type == "none"

        res["global"] = {}

        case config.name
        when "grub2", "grub2-efi"
          global = res["global"]
          export_grub2(global, config) if config.name == "grub2"
          export_grub2efi(global, config) if config.name == "grub2-efi"
          export_default(global, config.grub_default)
          export_password(global, config.password)
          res["global"]["cpu_mitigations"] = config.cpu_mitigations.value.to_s
        when "systemd-boot"
          res["global"]["timeout"] = config.menu_timeout
          res["global"]["secure_boot"] = config.secure_boot
        else
          raise UnsupportedBootloader, bootloader.name
        end
        # Do not export device map as device name are very unpredictable and is used only as
        # work-around when automatic ones do not work for what-ever reasons ( it can really safe
        # your day in L3 )

        res
      end

    private

      def import_grub2(data, bootloader)
        return unless bootloader.name == "grub2"

        GRUB2_BOOLEAN_MAPPING.each do |key, method|
          val = data.global.public_send(key)
          next unless val

          bootloader.public_send(:"#{method}=", val == "true")
        end
      end

      def import_grub2efi(data, bootloader)
        return unless bootloader.name == "grub2-efi"

        GRUB2EFI_BOOLEAN_MAPPING.each do |key, method|
          val = data.global.public_send(key)
          next unless val

          bootloader.public_send(:"#{method}=", val == "true")
        end
      end

      def import_password(data, bootloader)
        password = data.global.password
        return unless password

        pwd_object = bootloader.password
        pwd_object.used = true
        # default for encrypted is false, so use it only when exacly true
        if password.encrypted == "true"
          pwd_object.encrypted_password = password.value
        else
          pwd_object.password = password.value
        end

        # default for unrestricted is true, so disable it only when exactly false
        pwd_object.unrestricted = password.unrestricted != "false"
      end

      def import_default(data, default)
        # import first kernel params as cpu_mitigations can later modify it
        import_kernel_params(data, default)

        DEFAULT_BOOLEAN_MAPPING.each do |key, method|
          val = data.global.public_send(key)
          next unless val

          default.public_send(method).value = val == "true"
        end

        DEFAULT_STRING_MAPPING.each do |key, method|
          val = data.global.public_send(key)
          next unless val

          default.public_send(:"#{method}=", val)
        end

        DEFAULT_ARRAY_MAPPING.each do |key, method|
          val = data.global.public_send(key)
          next unless val

          default.public_send(:"#{method}=", val.split.map { |v| v.to_sym })
        end

        import_timeout(data, default)
      end

      def import_kernel_params(data, default)
        DEFAULT_KERNEL_PARAMS_MAPPING.each do |key, method|
          val = data.global.public_send(key)
          next unless val

          # import resume only if device exists (bsc#1187690)
          resume = val[/(?:\s|\A)resume=(\S+)/, 1]
          if resume && !Yast::BootStorage.staging.find_by_any_name(resume)
            log.warn "Remove 'resume' parameter due to usage of non existing device '#{resume}'"
            val = val.gsub(/(?:\s|\A)resume=#{Regexp.escape(resume)}/, "")
          end

          default.public_send(method).replace(val)
        end
      end

      def import_timeout(data, default)
        return unless data.global.timeout

        global = data.global
        if global.hiddenmenu == "true"
          default.timeout = "0"
          default.hidden_timeout = global.timeout.to_s if global.timeout
        else
          default.timeout = global.timeout.to_s if global.timeout
          default.hidden_timeout = "0"
        end
      end

      def import_device_map(data, bootloader)
        return unless bootloader.name == "grub2"
        return if !Yast::Arch.x86_64 && !Yast::Arch.i386

        dev_map = data.device_map
        return unless dev_map

        bootloader.device_map.clear_mapping
        dev_map.each do |entry|
          bootloader.device_map.add_mapping(entry.firmware, entry.linux)
        end
      end

      STAGE1_DEVICES_MAPPING = {
        "boot_root"     => :boot_partition_names,
        "boot_boot"     => :boot_partition_names,
        "boot_mbr"      => :boot_disk_names,
        "boot_extended" => :boot_partition_names
      }.freeze
      def import_stage1(data, bootloader)
        return unless bootloader.name == "grub2"

        stage1 = bootloader.stage1
        global = data.global

        stage1.generic_mbr = global.generic_mbr == "true" unless global.generic_mbr.nil?

        if !global.activate.nil?
          stage1.activate = global.activate == "true"
        # old one from SLE9 ages, it uses boolean and not string
        elsif !data.activate.nil?
          stage1.activate = data.activate
        end

        import_stage1_devices(data, stage1)
      end

      def import_stage1_devices(data, stage1)
        STAGE1_DEVICES_MAPPING.each do |key, method|
          next if data.global.public_send(key) != "true"

          stage1.public_send(method).each do |dev_name|
            stage1.add_udev_device(dev_name)
          end
        end

        import_custom_devices(data, stage1)
      end

      def import_custom_devices(data, stage1)
        # SLE9 way to define boot device
        if data.loader_device && !data.loader_device.empty?
          stage1.add_udev_device(data.loader_device)
        end

        global = data.global
        return if !global.boot_custom || global.boot_custom.empty?

        global.boot_custom.split(",").each do |dev|
          stage1.add_udev_device(dev.strip)
        end
      end

      def bootloader_from_data(data)
        loader_type = data.loader_type || BootloaderFactory::DEFAULT_KEYWORD
        allowed = BootloaderFactory.supported_names + [BootloaderFactory::DEFAULT_KEYWORD]

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
      GRUB2EFI_BOOLEAN_MAPPING = {
        "secure_boot"  => :secure_boot,
        "update_nvram" => :update_nvram
      }.freeze
      private_constant :GRUB2EFI_BOOLEAN_MAPPING
      def export_grub2efi(res, bootloader)
        GRUB2EFI_BOOLEAN_MAPPING.each do |key, method|
          val = bootloader.public_send(method)
          res[key] = val ? "true" : "false" unless val.nil?
        end
      end

      # only for grub2, not for others
      GRUB2_BOOLEAN_MAPPING = {
        "secure_boot"  => :secure_boot,
        "trusted_grub" => :trusted_boot,
        "update_nvram" => :update_nvram
      }.freeze
      private_constant :GRUB2_BOOLEAN_MAPPING
      def export_grub2(res, bootloader)
        GRUB2_BOOLEAN_MAPPING.each do |key, method|
          val = bootloader.public_send(method)
          res[key] = val ? "true" : "false" unless val.nil?
        end
      end

      DEFAULT_BOOLEAN_MAPPING = {
        "os_prober" => :os_prober
      }.freeze
      private_constant :DEFAULT_BOOLEAN_MAPPING

      DEFAULT_STRING_MAPPING = {
        "gfxmode" => :gfxmode,
        "serial"  => :serial_console
      }.freeze
      private_constant :DEFAULT_STRING_MAPPING

      DEFAULT_ARRAY_MAPPING = {
        "terminal" => :terminal
      }.freeze

      DEFAULT_KERNEL_PARAMS_MAPPING = {
        "append"            => :kernel_params,
        "xen_append"        => :xen_kernel_params,
        "xen_kernel_append" => :xen_hypervisor_params
      }.freeze
      private_constant :DEFAULT_KERNEL_PARAMS_MAPPING

      def export_default(res, default)
        DEFAULT_BOOLEAN_MAPPING.each do |key, method|
          val = default.public_send(method)
          res[key] = val.enabled? ? "true" : "false" if val.defined?
        end

        DEFAULT_KERNEL_PARAMS_MAPPING.each do |key, method|
          val = default.public_send(method)
          result = val.serialize
          # Do not export the 'resume' parameter as it depends on storage, which is not
          # cloned by default. The only exception is partition label which is cloned,
          # but we decided to be consistent and also remove it.
          # Anyways, 'resume' will be proposed if it's missing (bsc#1187690).
          result.gsub!(/(?:\s|\A)resume=\S+/, "")
          res[key] = result unless result.empty?
        end

        DEFAULT_STRING_MAPPING.each do |key, method|
          val = default.public_send(method)
          res[key] = val.to_s if val
        end

        DEFAULT_ARRAY_MAPPING.each do |key, method|
          val = default.public_send(method)
          res[key] = val.join(" ") if val
        end

        export_timeout(res, default)
      end

      def export_password(res, password)
        return unless password.used?

        res["password"] = {
          "unrestricted" => password.unrestricted? ? "true" : "false",
          "encrypted"    => "true",
          "value"        => password.encrypted_password
        }
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
  # rubocop:enable Metrics/ClassLength
end
