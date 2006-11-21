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
	BootZIPL.ycp

#	BootS390.ycp		\
#	BootMILO.ycp		\
#	BootABOOT.ycp

Bootloader_API.pm:
	test -f Bootloader_API.pm || ln -sf `find /usr/lib/perl5 -name Bootloader_API.pm | tail -1`


EXTRA_DIST = 			\
	$(module_DATA) 

bootloader:
	ln -sf .. bootloader

ycpchook = bootloader

dep: Bootloader_API.pm

BootCommon.ybc: Bootloader_API.pm

install: install_Bootloader_API install-am

install_Bootloader_API:
	test -d ${RPM_BUILD_ROOT}/@moduledir@ || mkdir -p ${RPM_BUILD_ROOT}/@moduledir@
	 /bin/cp -f -d Bootloader_API.pm ${RPM_BUILD_ROOT}/@moduledir@

include $(top_srcdir)/Makefile.am.common
