#
# Makefile.am for bootloader/src/fixchs
#


SOURCES = FixCHS.c

if MBR_I386

all: FixCHS
FixCHS: FixCHS.c
	gcc -L/usr/lib -m32 -O2 -Wall -o FixCHS FixCHS.c

ybin_SCRIPTS = FixCHS

endif

EXTRA_DIST = $(SOURCES)

