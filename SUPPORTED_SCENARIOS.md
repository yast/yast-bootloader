# Supported Scenarios

The goal of this document is to have a single source of information  which scenarios are supported by yast2-bootloader.

## bootloaders

* grub2
* grub2-efi
  * only for UEFI boot
  * only with GPT (see [bug](https://bugzilla.novell.com/show_bug.cgi?id=889733#c8))
* systemd-boot
  * only for UEFI boot
* none

# Partition table

* [DOS partition table](http://en.wikipedia.org/wiki/Master_boot_record)
* [GPT](http://en.wikipedia.org/wiki/GUID_Partition_Table)
  * requires [bios_boot partition](http://en.wikipedia.org/wiki/BIOS_Boot_partition) if stage1 will be on disk
* [DASD](http://en.wikipedia.org/wiki/Direct-access_storage_device)
  * only s390x

# storage configuration

* software RAID
  * /boot cannot be on RAID unless it is RAID1
  * cannot have stage1 on MD RAID1, so when /boot is on RAID1, then boot from MBR have to be used
* LVM
  * /boot cannot be encrypted (not bootloader limitation see [bug](https://bugzilla.novell.com/show_bug.cgi?id=890364#c40))
  * LVM can contain volumes on partition-less disks as long as at least one volume lives on partition
    and disk with such volume is first in boot order. see [bug](http://bugzilla.suse.com/show_bug.cgi?id=980529)
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
  * there's no requirement on the partition number
  * good PReP disk layout overview [PowerLinux Boot howto](https://www.ibm.com/developerworks/community/wikis/home?lang=en#!/wiki/W51a7ffcf4dfd_4b40_9d82_446ebc23c550/page/PowerLinux%20Boot%20howto)
  * boot code implemented in [SLOF - Slimline Open Firmware](https://github.com/aik/SLOF/blob/master/slof/fs/packages/disk-label.fs) - used e.g. by qemu
  * full reference (quite ancient) [CHRP](https://stuff.mit.edu/afs/sipb/contrib/doc/specs/protocol/chrp/)
* s390x
  * /boot/zipl must be on ext fs ( unless upgraded from working zipl configuration )
  * only GRUB2

# Stage1 locations

* MBR of disk where is /boot
* MBR of identical disks in MD RAID if it contains /boot [fate](https://fate.novell.com/316983)
* /boot
* extended partition
  * /boot has to be on a logical partition
  
# Required packages

As we've previously mentioned, we have 3 options for bootloaders: grub2, grub2-efi, and none. The bootloader option, the system configuration, and its architecture will define the required packages. Besides that, the system will always require the package <b>kexec-tools</b> unless the installation is happening through a live medium.

## grub2
This is the most common option and requires <b>grub2</b>. There is also special cases that may require additional packages:

* Generic mbr binary files will require the package <b>syslinux</b>.
* If using trusted boot option, systems with x86_64 and i386 architectures will require the packages <b>trustedgrub2</b> and <b>trustedgrub2-i386-pc</b>.

## grub2-efi
This option requires packages based on the architecture of the system:

* i386 architecture requires: <b>grub2-i386-efi</b>.
* x86_64 architecture requires: <b>grub2-x86_64-efi</b>. If secure boot is used, it also requires <b>shim</b> and <b>mokutil</b>.
* arm architecture requires: <b>grub2-arm-efi</b>.
* aarch64 architecture requires: <b>grub2-arm64-efi</b>.

## systemd-boot
If you're running a multiboot EFI system, systemd-boot can provide easier boot management and may even reduce your boot times.
Systemd-boot will be supported on x86_64 EFI architecture only.

## none
This option has no additional package requirement.
