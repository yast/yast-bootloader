#
# Makefile.am for bootloader/src
#

YCPCFLAGS = -I .

module_DATA =			\
	Bootloader.ycp		\
	BootCommon.ycp		\
	BootGRUB.ycp		\
	BootLILO.ycp		\
	BootELILO.ycp		\
	BootS390.ycp		\
	BootMILO.ycp		\
	BootABOOT.ycp		\
	BootSILO.ycp		\
	BootPPC.ycp

EXTRA_DIST = 			\
	$(module_DATA) 

include:
	mkdir include && ln -sf ../../ include/bootloader

ycpchook = include


include $(top_srcdir)/Makefile.am.common
