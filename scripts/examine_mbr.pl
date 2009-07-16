#!/usr/bin/perl

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
  exit 1;
}

if (substr($MBR, 320, 126) =~ 
    m,invalid partition table.*no operating system,i) {
  print "Generic MBR\n";
  exit 1;
}

if (substr($MBR, 346, 100) =~ m,GRUB .Geom.Hard Disk.Read. Error,) {
  print "Grub stage1\n";
  exit 1;
}

if (substr($MBR, 4, 20) =~ m,LILO,) {
  print "LILO stage1\n";
  exit 1;
}

if (substr($MBR, 12, 500) =~ m,NTLDR is missing,) {
  print "Windows bootloader stage1\n";
  exit 0;
}

if (substr($MBR, 0, 440) =~ 
    m,invalid partition table.*Error loading operating system,i) {
  print "Vista MBR\n";
  exit 0;
}


print "unknown\n";
exit 1;
