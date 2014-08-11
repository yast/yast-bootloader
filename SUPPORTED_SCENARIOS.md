# Supported Scenarios

Goal of this document is to have single source of information  which scenarios is supported by yast2-bootloader.

## bootloaders

* grub2
* grub2-efi
  * only for UEFI boot
* none
* grub
  * limited, only for opensuse and is not proposed now
  * only for x86 hardware

# Partition table

* DOS partition table
* GPT partition table
  * need bios_grub partition if stage1 is on MBR and /boot lives on BTRFS
  * /boot must be on partition 1..4

# storage configuration

* software raid
  * /boot cannot be on raid unless it is raid1
  * cannot have stage1 on md raid1 ( so no /boot on raid1 )
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
* MBR of identical disks in md raid if it contain /boot [fate](https://fate.novell.com/316983)
* /boot
* extended partition
  * only if /boot is on logical partition
