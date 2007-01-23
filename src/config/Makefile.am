#
# Makefile.am for bootloader/src
#

if I386_OR_AMD64

desktop_DATA = \
		bootloader.desktop

else

if S390

else

desktop_DATA = \
		bootloader.desktop

endif

endif

rncdir =  $(schemadir)/autoyast/rnc
rnc_DATA = bootloader.rnc

EXTRA_DIST = bootloader.desktop bootloader.rnc
