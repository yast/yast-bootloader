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

Booltloader_API.pm:
	test -f Bootloader_API.pm || ln -sf `find /usr/lib/perl5 -name Bootloader_API.pm`


EXTRA_DIST = 			\
	$(module_DATA) 

bootloader:
	ln -sf .. bootloader

ycpchook = bootloader

dep: Booltloader_API.pm

install: install_Bootloader_API

install_Bootloader_API:
	 /usr/bin/install -c -p -m 644 'Bootloader_API.pm' '/usr/share/YaST2/modules/Bootloader_API.pm'

include $(top_srcdir)/Makefile.am.common
