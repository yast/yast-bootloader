#
# Makefile.am for bootloader/installation/agents
#

scrconf_DATA = $(patsubst $(srcdir)/%,%,$(wildcard $(srcdir)/*.scr))

fillup_DATA = sysconfig.bootloader

fillupdir = /var/adm/fillup-templates

EXTRA_DIST = $(scrconf_DATA) $(fillup_DATA) 
