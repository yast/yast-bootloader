# Supported Scenarios

The goal of this document is to have a single source of information  which scenarios are supported by yast2-bootloader.

## bootloaders

* grub2
* grub2-efi
  * only for UEFI boot
  * only with GPT (see [bug](https://bugzilla.novell.com/show_bug.cgi?id=889733#c8))
* none
* grub
  * for openSUSE only, not proposed by default, likely to be removed
  * only for x86 hardware

# Partition table

* [DOS partition table](http://en.wikipedia.org/wiki/Master_boot_record)
* [GPT](http://en.wikipedia.org/wiki/GUID_Partition_Table)
  * requires [bios_boot partition](http://en.wikipedia.org/wiki/BIOS_Boot_partition) if stage1 will be on disk
* [DASD](http://en.wikipedia.org/wiki/Direct-access_storage_device)
  * only s390x

# storage configuration

* software RAID
  * /boot cannot be on RAID unless it is RAID1
  * cannot have stage1 on MD RAID1 ( so no /boot on RAID1 )
* LVM
  * /boot cannot be encrypted (not bootloader limitation see [bug](https://bugzilla.novell.com/show_bug.cgi?id=890364#c40))
* multipath
* Device mapper
* local hard disk (including USB/ieee1394)
* local (hardware) RAID array of any type
* BIOS-RAID (handled via DM-RAID or MD RAID)
* iSCSI server with persistent IP address / disk identification
* NFSv3,v4 share on server with fixed IP address


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
