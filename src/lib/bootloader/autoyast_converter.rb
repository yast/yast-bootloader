require "yast"

module Bootloader
  # Converter between internal configuration model and autoyast serialization of configuration.
  class AutoyastConverter
    class << self
      include Yast::Logger

      def import(_data)
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
