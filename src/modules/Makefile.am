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

symlinks:
	test -L bootloader || ln -sf .. bootloader

ycpchook = symlinks


include $(top_srcdir)/Makefile.am.common
