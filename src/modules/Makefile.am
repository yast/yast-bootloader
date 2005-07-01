#
# Makefile.am for bootloader/src
#

YCPCFLAGS = -I .

module_DATA =			\
	Bootloader.ycp		\
	BootCommon.ycp		\
	BootArch.ycp		\
	BootGRUB.ycp		\
	BootLILO.ycp		\
	BootZIPL.ycp

#	BootELILO.ycp		
#	BootS390.ycp		\
#	BootMILO.ycp		\
#	BootABOOT.ycp		\
#	BootPPC.ycp		



EXTRA_DIST = 			\
	$(module_DATA) 

bootloader:
	ln -sf .. bootloader

ycpchook = bootloader


include $(top_srcdir)/Makefile.am.common
