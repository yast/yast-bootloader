# TODO: create factory like method for Storage
{
  "/dev/sda" => {
    "unique"         => "3OOL.41o+EUK3QE2",
    "bus"            => "IDE",
    "device"         => "/dev/sda",
    "vendor"         => "HITACHI",
    "model"          => "HTS72323",
    "driver"         => "ahci",
    "driver_module"  => "ahci",
    "partitions"     => [
      {
        "device"         => "/dev/sda1",
        "name"           => "sda1",
        "used_by_type"   => :UB_NONE,
        "used_by_device" => "",
        "udev_path"      => "pci-0000:00:1f.2-scsi-0:0:0:0-part1",
        "udev_id"        => [
          "ata-HITACHI_HTS723232A7A364_E3834563C86LDM-part1",
          "scsi-1ATA_HITACHI_HTS723232A7A364_E3834563C86LDM-part1",
          "scsi-SATA_HITACHI_HTS72323_E3834563C86LDM-part1",
          "wwn-0x5000cca6d4c3bbb8-part1"
        ],
        "size_k"         => 2104515,
        "detected_fs"    => :unknown,
        "nr"             => 1,
        "fsid"           => 130,
        "fstype"         => "Linux swap",
        "region"         => [0, 262],
        "type"           => :primary
      },
      {
        "device"         => "/dev/sda2",
        "name"           => "sda2",
        "used_by_type"   => :UB_NONE,
        "used_by_device" => "",
        "udev_path"      => "pci-0000:00:1f.2-scsi-0:0:0:0-part2",
        "udev_id"        => [
          "ata-HITACHI_HTS723232A7A364_E3834563C86LDM-part2",
          "scsi-1ATA_HITACHI_HTS723232A7A364_E3834563C86LDM-part2",
          "scsi-SATA_HITACHI_HTS72323_E3834563C86LDM-part2",
          "wwn-0x5000cca6d4c3bbb8-part2"
        ],
        "size_k"         => 20980890,
        "detected_fs"    => :unknown,
        "nr"             => 2,
        "fsid"           => 131,
        "fstype"         => "Linux native",
        "region"         => [261, 2612],
        "type"           => :primary,
        "boot"           => true
      },
      {
        "device"         => "/dev/sda3",
        "name"           => "sda3",
        "used_by_type"   => :UB_NONE,
        "used_by_device" => "",
        "udev_path"      => "pci-0000:00:1f.2-scsi-0:0:0:0-part3",
        "udev_id"        => [
          "ata-HITACHI_HTS723232A7A364_E3834563C86LDM-part3",
          "scsi-1ATA_HITACHI_HTS723232A7A364_E3834563C86LDM-part3",
          "scsi-SATA_HITACHI_HTS72323_E3834563C86LDM-part3",
          "wwn-0x5000cca6d4c3bbb8-part3"
        ],
        "size_k"         => 289499332,
        "detected_fs"    => :unknown,
        "nr"             => 3,
        "fsid"           => 131,
        "fstype"         => "Linux native",
        "region"         => [2872, 36041],
        "type"           => :primary
      }
    ],
    "size_k"         => 312571224,
    "cyl_size"       => 8225280,
    "cyl_count"      => 38913,
    "sector_size"    => 512,
    "label"          => "msdos",
    "name"           => "sda",
    "max_logical"    => 255,
    "max_primary"    => 4,
    "type"           => :CT_DISK,
    "transport"      => :sata,
    "used_by_type"   => :UB_NONE,
    "used_by_device" => "",
    "udev_id"        => [
      "ata-HITACHI_HTS723232A7A364_E3834563C86LDM",
      "scsi-1ATA_HITACHI_HTS723232A7A364_E3834563C86LDM",
      "scsi-SATA_HITACHI_HTS72323_E3834563C86LDM",
      "wwn-0x5000cca6d4c3bbb8"],
    "udev_path"      => "pci-0000:00:1f.2-scsi-0:0:0:0"
  },
  "/dev/sdb" => {
    "unique"         => "uI_Q.Uy_iBFnqnWC",
    "bus"            => "SCSI",
    "device"         => "/dev/sdb",
    "vendor"         => "Linux",
    "model"          => "scsi_debug",
    "driver"         => "scsi_debug",
    "partitions"     => [
      {
        "device"         => "/dev/sdb1",
        "name"           => "sdb1",
        "used_by_type"   => :UB_NONE,
        "used_by_device" => "",
        "udev_path"      => "scsi-0:0:0:0-part1",
        "udev_id"        => [
          "scsi-1Linux_scsi_debug_16000-part1",
          "scsi-35333333000003e80-part1",
          "wwn-0x5333333000003e80-part1"
        ],
        "size_k"         => 64260,
        "detected_fs"    => :unknown,
        "nr"             => 1,
        "fsid"           => 65,
        "fstype"         => "PPC PReP Boot",
        "region"         => [0, 1],
        "type"           => :primary,
        "boot"           => true
      },
      {
        "device"         => "/dev/sdb2",
        "name"           => "sdb2",
        "used_by_type"   => :UB_NONE,
        "used_by_device" => "",
        "udev_path"      => "scsi-0:0:0:0-part2",
        "udev_id"        => [
          "scsi-1Linux_scsi_debug_16000-part2",
          "scsi-35333333000003e80-part2",
          "wwn-0x5333333000003e80-part2"
        ],
        "size_k"         => 4260,
        "detected_fs"    => :unknown,
        "nr"             => 2,
        "fsid"           => 65,
        "fstype"         => "PPC PReP Boot",
        "region"         => [0, 1],
        "type"           => :primary,
        "boot"           => true
      }
    ],
    "size_k"         => 307200,
    "cyl_size"       => 65802240,
    "cyl_count"      => 4,
    "sector_size"    => 4096,
    "label"          => "msdos",
    "name"           => "sdb",
    "max_logical"    => 255,
    "max_primary"    => 4,
    "type"           => :CT_DISK,
    "transport"      => :unknown,
    "used_by_type"   => :UB_NONE,
    "used_by_device" => "",
    "udev_id"        => [
      "scsi-1Linux_scsi_debug_16000",
      "scsi-35333333000003e80",
      "wwn-0x5333333000003e80"
    ],
    "udev_path"      => "scsi-0:0:0:0"
  }
}
