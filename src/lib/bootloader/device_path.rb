require "yast"

module Bootloader
  # Class for device path
  #
  # @example device path can be defined explicitly
  #   DevicePath.new("/devs/sda")
  # @example definition by UUID is translated to device path
  #   dev = DevicePath.new("UUID=\"0000-00-00\"")
  #   dev.path -> "/dev/disk/by-uuid/0000-00-00"
  class DevicePath
    attr_reader :path

    # Performs initialization
    #
    # @param dev [<String>] either a path like /dev/sda or special string for uuid or label
    def initialize(dev)
      @path =  if dev_by_uuid?(dev)
        # if defined by uuid, convert it
        File.realpath(dev.gsub(/UUID="([-a-zA-Z0-9]*)"/, '/dev/disk/by-uuid/\1'))
      elsif dev_by_label?(dev)
        # as well for label
        File.realpath(dev.gsub(/LABEL="(.*)"/, '/dev/disk/by-label/\1'))
      else
        # add it exactly (but whitespaces) as specified by the user
        dev.strip
      end
    end

    # @return [Boolean] true if the @path exists in the system
    def exists?
      File.exists?(path)
    end

    alias :valid? :exists?

  private

    def dev_by_uuid?(dev)
      dev =~ /UUID=".+"/
    end

    def dev_by_label?(dev)
      dev =~ /LABEL=".+"/
    end
  end
end
