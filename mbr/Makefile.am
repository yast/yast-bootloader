#
# Makefile.am for bootloader/mbr
#

datadir = /usr/share/YaST2/data

#ifdef MBR

all: mbr
mbr: mbr.S asm.h
	test -d machine || ln -s . machine
	gcc -c mbr.S -I. -o mbr.o
	ld -e start -Ttext 0x600 mbr.o -o mbr_tmp
	objcopy -O binary mbr_tmp mbr

SOURCES = mbr.S asm.h
data_DATA = mbr

EXTRA_DIST = $(SOURCES) $(data_DATA)

#endif

