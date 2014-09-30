{
  "/dev/tmpfs" => {
    "device"     => "/dev/tmpfs",
    "name"       => "tmpfs",
    "partitions" => [
      {
        "detected_fs"  => :tmpfs,
        "device"       => "tmpfs",
        "fstype"       => "TMPFS",
        "ignore_fstab" => true,
        "mount"        => "/dev/shm",
        "mountby"      => :device,
        "name"         => "none",
        "size_k"       => 510516,
        "type"         => :tmpfs,
        "used_fs"      => :tmpfs
      },
      {
        "detected_fs"  => :tmpfs,
        "device"       => "tmpfs",
        "fstype"       => "TMPFS",
        "ignore_fstab" => true,
        "mount"        => "/run",
        "mountby"      => :device,
        "name"         => "none",
        "size_k"       => 510516,
        "type"         => :tmpfs,
        "used_fs"      => :tmpfs
      },
      {
        "detected_fs"  => :tmpfs,
        "device"       => "tmpfs",
        "fstype"       => "TMPFS",
        "ignore_fstab" => true,
        "mount"        => "/sys/fs/cgroup",
        "mountby"      => :device,
        "name"         => "none",
        "size_k"       => 510516,
        "type"         => :tmpfs,
        "used_fs"      => :tmpfs
      },
      {
        "detected_fs"  => :tmpfs,
        "device"       => "tmpfs",
        "fstype"       => "TMPFS",
        "ignore_fstab" => true,
        "mount"        => "/var/lock",
        "mountby"      => :device,
        "name"         => "none",
        "size_k"       => 510516,
        "type"         => :tmpfs,
        "used_fs"      => :tmpfs
      },
      {
        "detected_fs"  => :tmpfs,
        "device"       => "tmpfs",
        "fstype"       => "TMPFS",
        "ignore_fstab" => true,
        "mount"        => "/var/run",
        "mountby"      => :device,
        "name"         => "none",
        "size_k"       => 510516,
        "type"         => :tmpfs,
        "used_fs"      => :tmpfs
      }
    ],
    "type"       => :CT_TMPFS
  },
  "/dev/vda"   => {
    "bios_id"       => "0x80",
    "bus"           => "None",
    "cyl_count"     => 1871,
    "cyl_size"      => 8225280,
    "device"        => "/dev/vda",
    "driver"        => "virtio-pci",
    "driver_module" => "virtio_pci",
    "label"         => "msdos",
    "max_logical"   => 15,
    "max_primary"   => 4,
    "name"          => "vda",
    "partitions"    => [
      {
        "boot"        => true,
        "detected_fs" => :ext3,
        "device"      => "/dev/vda1",
        "fsid"        => 131,
        "fstopt"      => "defaults",
        "fstype"      => "Linux native",
        "mount"       => "/",
        "mountby"     => :device,
        "name"        => "vda1",
        "nr"          => 1,
        "region"      => [0, 1807],
        "size_k"      => 14513703,
        "type"        => :primary,
        "used_fs"     => :ext3,
        "uuid"        => "ae751ebb-d184-4553-b902-2fe7d83905c4"
      },
      {
        "detected_fs" => :swap,
        "device"      => "/dev/vda2",
        "fsid"        => 130,
        "fstopt"      => "defaults",
        "fstype"      => "Linux swap",
        "mount"       => "swap",
        "mountby"     => :device,
        "name"        => "vda2",
        "nr"          => 2,
        "region"      => [1807, 64],
        "size_k"      => 514079,
        "type"        => :primary,
        "used_fs"     => :swap,
        "uuid"        => "efc95cda-3447-43ca-8f73-1257e256b3ff"
      }
    ],
    "sector_size"   => 512,
    "size_k"        => 15033344,
    "transport"     => :unknown,
    "type"          => :CT_DISK,
    "unique"        => "KSbE.Fxp0d3BezAE"
  }
}
