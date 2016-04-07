module Bootloader
  # Converter between internal configuration model and autoyast serialization of configuration.
  class AutoyastConverter
    class << self
      def import(_data)
      end

      def export(config)
        bootloader_type = config.name
        res = { "loader_type" => bootloader_type }

        return res if bootloader_type == "none"

        export_stage1(res, config.stage1) if config.respond_to?(:stage1)
        export_default(res, config.grub_default)
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
        res["global"] ||= {}
        STAGE1_MAPPING.each do |key, method|
          res["global"][key] = stage1.public_send(method) ? "true" : "false"
        end

        res["global"]["boot_custom"] = stage1.custom_devices.join(",")
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
          res["global"][key] = val.enabled? ? "true" : "false" if val.defined?
        end

        DEFAULT_STRING_MAPPING.each do |key, method|
          val = default.public_send(method)
          res["global"][key] = val if val
        end

        DEFAULT_KERNEL_PARAMS_MAPPING.each do |key, method|
          val = default.public_send(method)
          res["global"][key] = val.serialize unless val.empty?
        end

        export_timeout(res, default)
      end

      def export_timeout(res, default)
        if default.hidden_timeout.to_s.to_i > 0
          res["global"]["hiddenmenu"] = "true"
          res["global"]["timeout"] = default.hidden_timeout.to_s.to_i
        else
          res["global"]["hiddenmenu"] = "false"
          res["global"]["timeout"] = default.timeout.to_s.to_i
        end
      end
    end
  end
end
