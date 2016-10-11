List of Information Needed About Storage Configuration
======================================================

Mount Points
---------------

- what partition is mounted to "/" ( so it can be queried )
- what partition is mounted to "/boot" and if it is same as "/" ( so it can be queried )
- what partition is mounted to "/boot/zipl" ( only on s390 to query )
- what partition is mounted to "/boot/efi" ( only on efi based archs )

Partitions
---------------

- is partition logical ( so MBR have to be installed to extended one )
- extended partition for given disk ( needed only if /boot is on logical partition )
- file system of partition ( as some fs have problem embedding stage1 code, so do not propose to install it there )
- fsid of partition ( e.g. to detect `bios_grub` partition and others )
- if partition is part of MD, DM or Linux RAID ( target map now returns it, needed to decide if partition can be used for stage1 code )
  code check fsid to detect Linux RAID and sometimes it checks MD raid by `used_by` in target map. I expect it is no difference.
- raid level ( needed to check if it is 1, where we support redundancy boot from )
- if partition is freshly created or deleted ( well, for deleted is to not count partitions that will gone in installation, for creation it is used for prep partition chooser, as newly created prep is prefered as it will not overwrite existing code )
- if partition have boot flag ( bootloader ensure at least one partition have it and if requested, then also mark partition as one for boot )
- marking partition with boot flag ( currently done directly via parted, but in future it would be nice to have it in one location, marking partition means also ensuring that no other partition have it )
- where virtual partitions like EVMS, LVM, RAID ones, etc. layes on physical devices ( in some cases it have to use physical devices to write boot code )
- convert udev device to kernel name and also kernel name to udev name according to settings in storage ( mountby option ) ( needed for persistant storage names feature )
  this feature is used to get persistant names and also to recognize it. So if it is not yet available, then we use kernel names. Bootloader also need to know when it start
  to be available ( so when it is generated ). Currently it is quite heavily cached, so getting device is one look into map. If new storage code is fast enough, then cache can be removed.
- enlist all partitions that are prep ones ( `prep` or `gpt_prep` ) ( needed to decide where to install stage1 on powerpc )
- enlist all swap partitions with its size, and if swap is encrypted, then also detect it and use proper device ( allow user to choose any, but propose the biggest one )
- for encrypted devices provide info it is encrypted and also both devices name ( needed to use proper devices names, needed mainly for encrypted /boot and swap as mentioned above )
- is partition mounted by nfs ( when partition is on nfs, we have to skip writting bootloader code )
- convert raid with alternative name to standard name ( see bnc#944041 )

Disks
-----

- disk label like `GPT` or `DOS partition table` ( e.g. to propose correct generic MBR )
- where virtual disks like `LVM`, `RAID` ones, etc. layes on physical devices ( in some cases it have to use physical devices to write boot code )
- convert udev device to kernel name and also kernel name to udev name according to settings in storage ( mountby option )
- BIOS boot order ( needed mainly for `non-EFI` `x86_64` to enlist disks in device map )
