#
# Makefile.am for bootloader/mbr
#

datadir = @ydatadir@

SOURCES = mbr.S asm.h

if MBR_I386

all: mbr
mbr: mbr.S asm.h

	test -d machine || ln -s . machine
	gcc -m32 -c mbr.S -I. -o mbr.o
	ld -e start -Ttext 0x600 mbr.o -o mbr_tmp
	objcopy -O binary mbr_tmp mbr

data_DATA = mbr

endif

EXTRA_DIST = $(SOURCES)
