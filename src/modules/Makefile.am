#
# Makefile.am for bootloader/src
#

YCPCFLAGS = -I . -M .

module_DATA =			\
	Bootloader.ycp		\
	GfxMenu.ycp		\
	BootCommon.ycp		\
	BootArch.ycp		\
	BootELILO.ycp		\
	BootGRUB.ycp		\
	BootLILO.ycp		\
	BootPOWERLILO.ycp	\
	BootZIPL.ycp		\
	Bootloader_API.pm	\
	BootSupportCheck.ycp

#	BootS390.ycp		\
#	BootMILO.ycp		\
#	BootABOOT.ycp

Bootloader_API.pm:
	test -f Bootloader_API.pm || exit 1


EXTRA_DIST = 			\
	$(module_DATA) 

bootloader:
	ln -sf .. bootloader

ycpchook = bootloader

dep: Bootloader_API.pm

BootCommon.ybc: Bootloader_API.pm

install: install-am

include $(top_srcdir)/Makefile.am.common
