require "yast"

Yast.import "Arch"
Yast.import "BootStorage"

require "bootloader/stage1_device"

module Bootloader
  # Represents object that can set passed stage1 to proposed values.
  # It is highly coupled with Stage1 class and it is recommended to use
  # {Bootloader::Stage1#propose} instead of direct usage of this class.
  class Stage1Proposal
    include Yast::Logger

    # @param [Bootloader::Stage1] stage1 where write proposal
    def self.propose(stage1)
      arch = Yast::Arch.architecture
      proposal = AVAILABLE_PROPOSALS[arch]

      proposal.new(stage1).propose

      log.info "proposed stage1 configuration #{stage1.inspect}"
    end

  protected

    attr_reader :stage1

    def initialize(stage1)
      @stage1 = stage1
    end

    # Set "boot_*" flags in the globals map according to the boot device selected
    # with parameter selected_location. Only a single boot device can be selected
    # with this function. The function cannot be used to set a custom boot device.
    # It will always be deleted.
    #
    # FIXME: `mbr_md is probably unneeded; AFA we can see, this decision is
    # automatic anyway and perl-Bootloader should be able to make it without help
    # from the user or the proposal.
    #
    # @param [Symbol, Array] selected_location symbol one of :boot, :root, :mbr,
    #   :extended, `none or Array with first value :custom and second device for
    #   custom devices
    def assign_bootloader_device(selected_location)
      log.info "assign bootloader device '#{selected_location.inspect}'"
      # first, default to all off:
      stage1.clear_devices

      case selected_location
      when :root then stage1.add_udev_device(Yast::BootStorage.RootPartitionDevice)
      when :boot then stage1.add_udev_device(Yast::BootStorage.BootPartitionDevice)
      when :extended then stage1.add_udev_device(extended_partition)
      when :mbr then stage1.add_udev_device(Yast::BootStorage.mbr_disk)
      when :none then log.info "Resetting bootloader device"
      when Array
        if selected_location.first != :custom
          raise "Unknown value to select bootloader device #{selected_location.inspect}"
        end

        stage1.model.add_device(selected_location[1]) # add directly proposed value without changes
      else
        raise "Unknown value to select bootloader device #{selected_location.inspect}"
      end
    end

    # x86_64 specific stage1 proposal
    class X64 < Stage1Proposal
      using Y2Storage::Refinements::DevicegraphLists

      def propose
        selected_location = propose_boot_location
        log.info "propose_x86 (#{selected_location})"

        # set active flag, if needed
        if selected_location == :mbr
          # We are installing into MBR:
          # If there is an active partition, then we do not need to activate
          # one (otherwise we do).
          # Reason: if we use our own MBR code, we do not rely on the activate
          # flag in the partition table to boot Linux. Thus, the activated
          # partition can remain activated, which causes less problems with
          # other installed OSes like Windows (older versions assign the C:
          # drive letter to the activated partition).
          used_disks = ::Bootloader::Stage1Device.new(Yast::BootStorage.mbr_disk).real_devices
          stage1.activate = used_disks.any? { |d| any_boot_flag_partition?(d) }
          stage1.generic_mbr = false
        else
          # if not installing to MBR, always activate (so the generic MBR will
          # boot Linux)
          stage1.activate = true
          stage1.generic_mbr = true
        end
      end

    private

      def any_boot_flag_partition?(disk_name)
        disks = devicegraph.disks.with(name: disk_name)
        legacy_boot = disks.first.partition_table.partition_legacy_boot_flag_supported?
        disks.partitions.any? do |p|
          legacy_boot ? p.legacy_boot? : p.boot?
        end
      end

      def devicegraph
        Y2Storage::StorageManager.instance.staging
      end

      def propose_boot_location
        selected_location = :mbr

        # there was check if boot device is on logical partition
        # IMO it is good idea check MBR also in this case
        # see bug #279837 comment #53
        selected_location = separated_boot? ? :boot : :root if boot_partition_on_mbr_disk?

        if logical_boot? && extended_partition
          log.info "/boot is on logical partition and extended detected, extended proposed"
          selected_location = :extended
        end

        # for separate btrfs partition prefer MBR (bnc#940797)
        if boot_with_btrfs? && (logical_boot? || separated_boot?)
          log.info "/boot is on logical partition or separated and uses btrfs, mbr is preferred"
          selected_location = :mbr
        end

        if !stage1.can_use_boot?
          log.info "/boot cannot be used to install stage1"
          selected_location = :mbr
        end

        assign_bootloader_device(selected_location)

        selected_location
      end

      def separated_boot?
        Yast::BootStorage.separated_boot?
      end

      def extended_partition
        init_boot_info unless @boot_initialized

        @extended
      end

      def logical_boot?
        init_boot_info unless @boot_initialized

        @logical_boot
      end

      def boot_with_btrfs?
        init_boot_info unless @boot_initialized

        @boot_with_btrfs
      end

      def init_boot_info
        return if @boot_initialized
        @boot_initialized = true

        boot_part = devicegraph.partitions.with(name: Yast::BootStorage.BootPartitionDevice).first
        @logical_boot = boot_part.type == Storage::PartitionType_LOGICAL
        @boot_with_btrfs = with_btrfs?(boot_part)

        # check for sure also underlaying partitions
        disk_name = Yast::BootStorage.disk_with_boot_partition
        devicegraph.disks.with(name: disk_name).partitions.each do |p|
          @extended = p.name if p.type == Storage::PartitionType_EXTENDED
          next unless underlaying_boot_partition_devices.include?(p.name)

          @boot_with_btrfs = with_btrfs?(p)
          @logical_boot = true if p.type == Storage::PartitionType_LOGICAL
        end
      end

      def with_btrfs?(partition)
        partition.filesystem.type == ::Storage::FsType_BTRFS
      rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
        # No filesystem in the partition
        false
      end

      # determine the underlaying devices for the "/boot" partition (either the
      # BootPartitionDevice, or the devices from which the soft-RAID device for
      # "/boot" is built)
      def underlaying_boot_partition_devices
        @underlaying_boot_partition_devices ||=
          ::Bootloader::Stage1Device.new(Yast::BootStorage.BootPartitionDevice).real_devices
      end

      def boot_partition_on_mbr_disk?
        underlaying_boot_partition_devices.any? do |dev|
          disk = devicegraph.disks.with_name_or_partition(dev).first
          disk && disk.name == Yast::BootStorage.mbr_disk
        end
      end
    end

    # s390x specific stage1 proposal
    class S390 < Stage1Proposal
      def propose
        # s390 do not need any partition as it is stored to predefined zipl location
        assign_bootloader_device(:none)

        stage1.activate = false
        stage1.generic_mbr = false
      end
    end

    # ppc64le specific stage1 proposal
    class PPC < Stage1Proposal
      def propose
        partition = proposed_prep_partition
        if partition
          assign_bootloader_device([:custom, partition])

          stage1.activate = !on_gpt?(partition) # do not activate on gpt disks see (bnc#983194)
          stage1.generic_mbr = false
        # handle diskless setup, in such case do not write boot code anywhere
        # (bnc#874466)
        # we need to detect what is mount on /boot and if it is nfs, then just
        # skip this proposal. In other case if it is not nfs, then it is error
        # and raise exception.
        # powernv do not have prep partition, so we do not have any partition
        # to activate (bnc#970582)
        elsif Yast::BootStorage.disk_with_boot_partition == "/dev/nfs" || Yast::Arch.board_powernv
          stage1.activate = false
          stage1.generic_mbr = false
          return
        else
          raise "there is no prep partition"
        end
      end

    private

      def proposed_prep_partition
        partitions = Yast::BootStorage.prep_partitions

        created = partitions.find do |part|
          part_map = Yast::Storage.GetPartition(Yast::Storage.GetTargetMap, part)
          part_map["create"] == true
        end

        if created
          log.info "using freshly created prep partition #{created}"
          return created
        end

        same_disk_part = partitions.find do |part|
          disk = Yast::Storage.GetDiskPartition(part)["disk"]
          Yast::BootStorage.disk_with_boot_partition == disk
        end

        if same_disk_part
          log.info "using prep on boot disk #{same_disk_part}"
          return same_disk_part
        end

        log.info "nothing better so lets return first available prep"
        partitions.first
      end

      def on_gpt?(partition)
        target_map = Yast::Storage.GetTargetMap
        real_partitions = Bootloader::Stage1Device.new(partition).real_devices
        disks = real_partitions.map { |p| Yast::Storage.GetDisk(target_map, p) }
        disks.any? { |d| d["label"] == "gpt" }
      end
    end

    AVAILABLE_PROPOSALS = { # rubocop:disable Style/MutableConstant default_proc conflict
      "i386"    => X64,
      "x86_64"  => X64,
      "s390_32" => S390,
      "s390_64" => S390,
      "ppc"     => PPC,
      "ppc64"   => PPC
    }
    AVAILABLE_PROPOSALS.default_proc = lambda { |_h, k| raise "unsuported architecture #{k}" }
  end
end
