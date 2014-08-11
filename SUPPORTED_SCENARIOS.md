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

* DOS partition table
* GPT partition table
  * requires [bios_boot partition](http://en.wikipedia.org/wiki/BIOS_Boot_partition)if stage1 is on MBR and /boot lives on partition with BTRFS
  * /boot must be on partition 1..4

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
  * there must be at least one prep partition
* s390x
  * /boot/zipl must be on ext fs ( unless upgraded from working zipl configuration )
  * only GRUB2

# Stage1 locations

* MBR of disk where is /boot
* MBR of identical disks in MD RAID if it contain /boot [fate](https://fate.novell.com/316983)
* /boot
* extended partition
  * /boot has to be on a logical partition
