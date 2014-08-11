# Supported Scenarios

The goal of this document is to have a single source of information  which scenarios are supported by yast2-bootloader.

## bootloaders

* grub2
* grub2-efi
  * only for UEFI boot
* none
* grub
  * for openSUSE only, not proposed by default, likely to be removed
  * only for x86 hardware

# Partition table

* [DOS partition table](http://en.wikipedia.org/wiki/Master_boot_record)
* [GPT](http://en.wikipedia.org/wiki/GUID_Partition_Table)
  * requires [bios_boot partition](http://en.wikipedia.org/wiki/BIOS_Boot_partition)if stage1 is on MBR and /boot lives on partition with BTRFS
  * /boot must be on partition 1..4
* [DASD](http://en.wikipedia.org/wiki/Direct-access_storage_device)
  * only s390x

# storage configuration

* software RAID
  * /boot cannot be on RAID unless it is RAID1
  * cannot have stage1 on MD RAID1 ( so no /boot on RAID1 )
* LVM
  * fully supported
* multipath
  * fully supported
* Device mapper
  * fully supported

# Architectures

* x86
* x86_64
* ppc64(le and be)
  * only GRUB2
  * there must be at least one [PReP partition](http://en.wikipedia.org/wiki/Partition_type#List_of_partition_IDs) which size must not exceed 8MB (see [fate](https://fate.suse.com/317302))
* s390x
  * /boot/zipl must be on ext fs ( unless upgraded from working zipl configuration )
  * only GRUB2

# Stage1 locations

* MBR of disk where is /boot
* MBR of identical disks in MD RAID if it contains /boot [fate](https://fate.novell.com/316983)
* /boot
* extended partition
  * /boot has to be on a logical partition
