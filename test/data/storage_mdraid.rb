{
  "/dev/btrfs" => {
    "device"         => "/dev/btrfs",
    "name"           => "btrfs",
    "partitions"     => [],
    "type"           => :CT_BTRFS,
    "used_by_device" => "",
    "used_by_type"   => :UB_NONE
  },
  "/dev/md"    => {
    "device"         => "/dev/md",
    "name"           => "md",
    "partitions"     => [
      {
        "chunk_size"     => 64,
        "create"         => true,
        "detected_fs"    => :btrfs,
        "device"         => "/dev/md0",
        "devices"        => [
          "/dev/vda2",
          "/dev/vdb2",
          "/dev/vdc2",
          "/dev/vdd2"
        ],
        "format"         => true,
        "fstype"         => "MD RAID",
        "inactive"       => true,
        "mount"          => "/",
        "mountby"        => :uuid,
        "name"           => "md0",
        "nr"             => 0,
        "raid_type"      => "raid1",
        "sb_ver"         => "01.00.00",
        "size_k"         => 5_429_970,
        "subvol"         => [
          {
            "create" => true,
            "name"   => "boot/grub2/i386-pc"
          },
          {
            "create" => true,
            "name"   => "boot/grub2/x86_64-efi"
          },
          {
            "create" => true,
            "name"   => "home"
          },
          {
            "create" => true,
            "name"   => "opt"
          },
          {
            "create" => true,
            "name"   => "srv"
          },
          {
            "create" => true,
            "name"   => "tmp"
          },
          {
            "create" => true,
            "name"   => "usr/local"
          },
          {
            "create" => true,
            "name"   => "var/crash"
          },
          {
            "create" => true,
            "name"   => "var/lib/mailman"
          },
          {
            "create" => true,
            "name"   => "var/lib/named"
          },
          {
            "create" => true,
            "name"   => "var/lib/pgsql"
          },
          {
            "create" => true,
            "name"   => "var/log"
          },
          {
            "create" => true,
            "name"   => "var/opt"
          },
          {
            "create" => true,
            "name"   => "var/spool"
          },
          {
            "create" => true,
            "name"   => "var/tmp"
          }
        ],
        "type"           => :sw_raid,
        "used_by"        => [
          {
            "device" => "12345",
            "type"   => :UB_BTRFS
          }
        ],
        "used_by_device" => "12345",
        "used_by_type"   => :UB_BTRFS,
        "used_fs"        => :btrfs,
        "userdata"       => {
          "/" => "snapshots"
        },
        "uuid"           => "12345"
      },
      {
        "chunk_size"     => 4,
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/md1",
        "devices"        => [
          "/dev/vda1",
          "/dev/vdb1",
          "/dev/vdc1",
          "/dev/vdd1"
        ],
        "format"         => true,
        "fs_options"     => {
          "opt_dir_index"       => {
            "option_cmd"   => :mkfs,
            "option_str"   => "-O dir_index",
            "option_value" => true
          },
          "opt_reg_checks"      => {
            "option_cmd"   => :tunefs,
            "option_str"   => "-c 0 -i 0",
            "option_value" => true
          },
          "opt_reserved_blocks" => {
            "option_cmd"   => :mkfs,
            "option_str"   => "-m",
            "option_value" => "5.0"
          }
        },
        "fstopt"         => "acl,user_xattr",
        "fstype"         => "MD RAID",
        "inactive"       => true,
        "mkfs_opt"       => "-O dir_index -m5.0",
        "mount"          => "/boot",
        "mountby"        => :uuid,
        "name"           => "md1",
        "nr"             => 1,
        "raid_type"      => "raid1",
        "sb_ver"         => "01.00.00",
        "size_k"         => 305_235,
        "tunefs_opt"     => "-c 0 -i 0",
        "type"           => :sw_raid,
        "used_by_device" => "",
        "used_by_type"   => :UB_NONE,
        "used_fs"        => :ext4
      },
      {
        "chunk_size"     => 32,
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/md2",
        "devices"        => [
          "/dev/vda3",
          "/dev/vdb3",
          "/dev/vdc3",
          "/dev/vdd3"
        ],
        "format"         => true,
        "fstype"         => "MD RAID",
        "inactive"       => true,
        "mount"          => "swap",
        "mountby"        => :uuid,
        "name"           => "md2",
        "nr"             => 2,
        "raid_type"      => "raid0",
        "sb_ver"         => "01.00.00",
        "size_k"         => 417_688,
        "type"           => :sw_raid,
        "used_by_device" => "",
        "used_by_type"   => :UB_NONE,
        "used_fs"        => :swap
      }
    ],
    "type"           => :CT_MD,
    "used_by_device" => "",
    "used_by_type"   => :UB_NONE
  },
  "/dev/vda"   => {
    "bus"            => "None",
    "cyl_count"      => 1_305,
    "cyl_size"       => 8_225_280,
    "device"         => "/dev/vda",
    "driver"         => "virtio-pci",
    "driver_module"  => "virtio_pci",
    "label"          => "msdos",
    "max_logical"    => 15,
    "max_primary"    => 4,
    "name"           => "vda",
    "partitions"     => [
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vda1",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vda1",
        "nr"             => 1,
        "region"         => [0, 38],
        "size_k"         => 305_235,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md1",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md1",
        "used_by_type"   => :UB_MD
      },
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vda2",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vda2",
        "nr"             => 2,
        "region"         => [38, 676],
        "size_k"         => 5_429_970,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md0",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md0",
        "used_by_type"   => :UB_MD
      },
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vda3",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vda3",
        "nr"             => 3,
        "region"         => [714, 13],
        "size_k"         => 104_422,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md2",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md2",
        "used_by_type"   => :UB_MD
      }
    ],
    "proposal_name"  => "1. Disk, 10.00 GiB, /dev/vda,",
    "sector_size"    => 512,
    "size_k"         => 10_485_760,
    "transport"      => :unknown,
    "type"           => :CT_DISK,
    "unique"         => "KSbE.Fxp0d3BezAE",
    "used_by_device" => "",
    "used_by_type"   => :UB_NONE
  },
  "/dev/vdb"   => {
    "bus"            => "None",
    "cyl_count"      => 1_305,
    "cyl_size"       => 8_225_280,
    "device"         => "/dev/vdb",
    "driver"         => "virtio-pci",
    "driver_module"  => "virtio_pci",
    "label"          => "msdos",
    "max_logical"    => 15,
    "max_primary"    => 4,
    "name"           => "vdb",
    "partitions"     => [
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vdb1",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vdb1",
        "nr"             => 1,
        "region"         => [0, 38],
        "size_k"         => 305_235,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md1",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md1",
        "used_by_type"   => :UB_MD
      },
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vdb2",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vdb2",
        "nr"             => 2,
        "region"         => [38, 676],
        "size_k"         => 5_429_970,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md0",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md0",
        "used_by_type"   => :UB_MD
      },
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vdb3",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vdb3",
        "nr"             => 3,
        "region"         => [714, 13],
        "size_k"         => 104_422,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md2",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md2",
        "used_by_type"   => :UB_MD
      }
    ],
    "proposal_name"  => "2. Disk, 10.00 GiB, /dev/vdb, ",
    "sector_size"    => 512,
    "size_k"         => 10_485_760,
    "transport"      => :unknown,
    "type"           => :CT_DISK,
    "unique"         => "ndrI.Fxp0d3BezAE",
    "used_by_device" => "",
    "used_by_type"   => :UB_NONE
  },
  "/dev/vdc"   => {
    "bus"            => "None",
    "cyl_count"      => 1_305,
    "cyl_size"       => 8_225_280,
    "device"         => "/dev/vdc",
    "driver"         => "virtio-pci",
    "driver_module"  => "virtio_pci",
    "label"          => "msdos",
    "max_logical"    => 15,
    "max_primary"    => 4,
    "name"           => "vdc",
    "partitions"     => [
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vdc1",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vdc1",
        "nr"             => 1,
        "region"         => [0, 38],
        "size_k"         => 305_235,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md1",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md1",
        "used_by_type"   => :UB_MD
      },
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vdc2",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vdc2",
        "nr"             => 2,
        "region"         => [38, 676],
        "size_k"         => 5_429_970,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md0",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md0",
        "used_by_type"   => :UB_MD
      },
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vdc3",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vdc3",
        "nr"             => 3,
        "region"         => [714, 13],
        "size_k"         => 104_422,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md2",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md2",
        "used_by_type"   => :UB_MD
      }
    ],
    "proposal_name"  => "3. Disk, 10.00 GiB, /dev/vdc, ",
    "sector_size"    => 512,
    "size_k"         => 10_485_760,
    "transport"      => :unknown,
    "type"           => :CT_DISK,
    "unique"         => "Ep5N.Fxp0d3BezAE",
    "used_by_device" => "",
    "used_by_type"   => :UB_NONE
  },
  "/dev/vdd"   => {
    "bus"            => "None",
    "cyl_count"      => 1_305,
    "cyl_size"       => 8_225_280,
    "device"         => "/dev/vdd",
    "driver"         => "virtio-pci",
    "driver_module"  => "virtio_pci",
    "label"          => "msdos",
    "max_logical"    => 15,
    "max_primary"    => 4,
    "name"           => "vdd",
    "partitions"     => [
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vdd1",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vdd1",
        "nr"             => 1,
        "region"         => [0, 38],
        "size_k"         => 305_235,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md1",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md1",
        "used_by_type"   => :UB_MD
      },
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vdd2",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vdd2",
        "nr"             => 2,
        "region"         => [38, 676],
        "size_k"         => 5_429_970,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md0",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md0",
        "used_by_type"   => :UB_MD
      },
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/vdd3",
        "fsid"           => 253,
        "fstype"         => "Linux RAID",
        "name"           => "vdd3",
        "nr"             => 3,
        "region"         => [714, 13],
        "size_k"         => 104_422,
        "type"           => :primary,
        "used_by"        => [
          {
            "device" => "/dev/md2",
            "type"   => :UB_MD
          }
        ],
        "used_by_device" => "/dev/md2",
        "used_by_type"   => :UB_MD
      }
    ],
    "proposal_name"  => "4. Disk, 10.00 GiB, /dev/vdd, ",
    "sector_size"    => 512,
    "size_k"         => 10_485_760,
    "transport"      => :unknown,
    "type"           => :CT_DISK,
    "unique"         => "h_LR.Fxp0d3BezAE",
    "used_by_device" => "",
    "used_by_type"   => :UB_NONE
  }
}

