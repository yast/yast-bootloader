module Bootloader
  class AutoyastConverter
    class << self
      def import(data)
      end

      def export(config)
        bootloader_type = config.name
        res = { "loader_type" => bootloader_type }

        return res if bootloader_type == "none"

        export_stage1(res, config.stage1) if config.respond_to?(:stage1)
      end

    private

      STAGE1_MAPPING = {
        "activate" => :activate?,
        "generic_mbr" => :generic_mbr?,
        "boot_root" => :root_partition?,
        "boot_boot" => :boot_partition?,
        "boot_mbr" => :mbr?,
        "boot_extended" => :extended_partition?
      }
      def export_stage1(res, stage1)
        res["global"] ||= {}
        STAGE1_MAPPING.each do |key, method|
          res["global"][key] = stage1.public_send(method) ? "true" : "false"
        end

        res["global"]["boot_custom"] = stage1.custom_devices.join(",")
      end
    end
  end
end
