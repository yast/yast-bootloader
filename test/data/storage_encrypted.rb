{
  "/dev/sda" => {
    "bios_id"        => "0x80",
    "bus"            => "IDE",
    "cyl_count"      => 1_827,
    "cyl_size"       => 8_225_280,
    "device"         => "/dev/sda",
    "driver"         => "ahci",
    "driver_module"  => "ahci",
    "label"          => "msdos",
    "max_logical"    => 255,
    "max_primary"    => 4,
    "model"          => "HARDDISK",
    "name"           => "sda",
    "partitions"     => [
      {
        "create"         => true,
        "crypt_device"   => "/dev/mapper/cr_swap",
        "detected_fs"    => :swap,
        "device"         => "/dev/sda1",
        "enc_type"       => :luks,
        "format"         => true,
        "fsid"           => 130,
        "fstopt"         => "defaults",
        "fstype"         => "Linux swap",
        "inactive"       => true,
        "mount"          => "swap",
        "mountby"        => :device,
        "name"           => "sda1",
        "nr"             => 1,
        "region"         => [0, 261],
        "size_k"         => 2_096_482,
        "type"           => :primary,
        "udev_id"        => [
          "ata-VBOX_HARDDISK_VB7c7aa34e-2f09570d-part1",
          "scsi-0ATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d-part1",
          "scsi-1ATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d-part1",
          "scsi-SATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d-part1"
        ],
        "udev_path"      => "pci-0000:00:0d.0-ata-1.0-part1",
        "used_by_device" => "",
        "used_by_type"   => :UB_NONE,
        "used_fs"        => :swap
      },
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/sda2",
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
        "fsid"           => 131,
        "fstopt"         => "acl,user_xattr",
        "fstype"         => "Linux native",
        "inactive"       => true,
        "mkfs_opt"       => "-O dir_index -m5.0",
        "mount"          => "/boot",
        "mountby"        => :uuid,
        "name"           => "sda2",
        "nr"             => 2,
        "region"         => [261, 25],
        "size_k"         => 200_812,
        "tunefs_opt"     => "-c 0 -i 0",
        "type"           => :primary,
        "udev_id"        => [
          "ata-VBOX_HARDDISK_VB7c7aa34e-2f09570d-part2",
          "scsi-0ATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d-part2",
          "scsi-1ATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d-part2",
          "scsi-SATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d-part2"
        ],
        "udev_path"      => "pci-0000:00:0d.0-ata-1.0-part2",
        "used_by_device" => "",
        "used_by_type"   => :UB_NONE,
        "used_fs"        => :ext4,
        "userdata"       => { "/" => "snapshots" }
      },
      {
        "create"         => true,
        "detected_fs"    => :unknown,
        "device"         => "/dev/sda3",
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
        "fsid"           => 131,
        "fstopt"         => "acl,user_xattr",
        "fstype"         => "Linux native",
        "inactive"       => true,
        "mkfs_opt"       => "-O dir_index -m5.0",
        "mount"          => "/",
        "mountby"        => :uuid,
        "name"           => "sda3",
        "nr"             => 3,
        "region"         => [286, 1_540],
        "size_k"         => 12_370_050,
        "tunefs_opt"     => "-c 0 -i 0",
        "type"           => :primary,
        "udev_id"        => [
          "ata-VBOX_HARDDISK_VB7c7aa34e-2f09570d-part3",
          "scsi-0ATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d-part3",
          "scsi-1ATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d-part3",
          "scsi-SATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d-part3"
        ],
        "udev_path"      => "pci-0000:00:0d.0-ata-1.0-part3",
        "used_by_device" => "",
        "used_by_type"   => :UB_NONE,
        "used_fs"        => :ext4,
        "userdata"       => { "/" => "snapshots" }
      }
    ],
    "proposal_name"  => "1. IDE Disk, 14.00 GiB, /dev/sda, VBOX-HARDDISK",
    "sector_size"    => 512,
    "size_k"         => 14_680_064,
    "transport"      => :sata,
    "type"           => :CT_DISK,
    "udev_id"        => [
      "ata-VBOX_HARDDISK_VB7c7aa34e-2f09570d",
      "scsi-0ATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d",
      "scsi-1ATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d",
      "scsi-SATA_VBOX_HARDDISK_VB7c7aa34e-2f09570d"
    ],
    "udev_path"      => "pci-0000:00:0d.0-ata-1.0",
    "unique"         => "3OOL.LBw4GrqrKS7",
    "used_by_device" => "",
    "used_by_type"   => :UB_NONE,
    "vendor"         => "VBOX"
  }
}
