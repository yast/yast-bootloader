#
# Makefile.am for bootloader/installation/agents
#

scrconf_DATA = $(patsubst $(srcdir)/%,%,$(wildcard $(srcdir)/*.scr))

fillup_DATA = sysconfig.bootloader

fillupdir = /var/adm/fillup-templates

EXTRA_DIST = $(scrconf_DATA) $(fillup_DATA) 

if I386_OR_AMD64
sysconfig.bootloader : sysconfig.bootloader.i386
	cp sysconfig.bootloader.i386 sysconfig.bootloader
else
sysconfig.bootloader : sysconfig.bootloader.default
	cp sysconfig.bootloader.default sysconfig.bootloader
endif



