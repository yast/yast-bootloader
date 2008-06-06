#!/usr/bin/perl

#
# Examine an MBR and print what kind of bootloader stage1 code has been found.
#
# Exit codes:
#
#   0   : do not update the code in this MBR, it is either not maintained by us
#         (but belongs to some other OS) or some other unknown/unidentified
#         (bootloader?) code that we should not touch
#
# 254   : found known bootloader code that needs to be updated when the boot
#         setup is changing (because it contains a disk pointer to the next
#         bootloader stage, which may have changed)
#
#   1 -
# xxx   : some error occured while opening or reading from the (device) file
#         that contains the MBR
#         (254 is currently not produced as a system error code, and is not
#         expected to be produced; this script does not return error codes from
#         external commands; when no error code is set, this script exits with
#         code 255)
#

use Compress::Zlib;

die "must specify 1 device file to examine" unless @ARGV == 1;

open(FD, "<" . $ARGV[0]) || die "cannot open " . $ARGV[0];

die "cannot read 512 bytes from $1" unless sysread(FD, $MBR, 512, 0) == 512;

($d, $status) = deflateInit( -Level => Z_BEST_COMPRESSION );

($out, $status) = $d->deflate($MBR) ;
($out2, $status) = $d->flush() ;

$out .= $out2;

if (length($out) < 70) {
  print "Definitely invalid\n";
  exit 254;
}

if (substr($MBR, 320, 126) =~ 
    m,invalid partition table.*no operating system,i) {
  print "Generic MBR\n";
  exit 0;
}

if (substr($MBR, 346, 100) =~ m,GRUB .Geom.Hard Disk.Read. Error,) {
  print "Grub stage1\n";
  exit 254;
}

if (substr($MBR, 4, 20) =~ m,LILO,) {
  print "LILO stage1\n";
  exit 1;
}

if (substr($MBR, 12, 500) =~ m,NTLDR is missing,) {
  print "Windows bootloader stage1\n";
  exit 0;
}

if (substr($MBR, 320, 126) =~ 
    m,invalid partition table.*Error loading operating system,i) {
  print "Vista MBR\n";
  exit 200;
}


print "unknown\n";
exit 0;

