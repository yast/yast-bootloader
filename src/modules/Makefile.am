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
	BootPOWERLILO.ycp	\
	BootZIPL.ycp

#	BootS390.ycp		\
#	BootMILO.ycp		\
#	BootABOOT.ycp		\
#	BootELILO.ycp		

Booltloader_API.pm:
	test -f Bootloader_API.pm || ln -sf `find /usr/lib/perl5 -name Bootloader_API.pm`


EXTRA_DIST = 			\
	$(module_DATA) 

bootloader:
	ln -sf .. bootloader

ycpchook = bootloader

dep: Booltloader_API.pm

BootCommon.ybc: Booltloader_API.pm

install: install_Bootloader_API install-am

install_Bootloader_API:
	test -d ${RPM_BUILD_ROOT}/@moduledir@ || mkdir -p ${RPM_BUILD_ROOT}/@moduledir@
	 /bin/cp -f -d Bootloader_API.pm ${RPM_BUILD_ROOT}/@moduledir@

include $(top_srcdir)/Makefile.am.common
