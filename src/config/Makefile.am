#
# Makefile.am for bootloader/src
#

if S390

config_DATA =

else

config_DATA = \
		bootloader.y2cc	\
	  	bootfloppy.y2cc

desktop_DATA = \
		bootloader.desktop \
	  	bootfloppy.desktop

endif


EXTRA_DIST = $(config_DATA) $(desktop_DATA)
