#
# Makefile.am for bootloader/lilo/src
#

client_DATA =		\
	lilo.ycp	\
	lilo_write.ycp	\
	lilo_auto.ycp

yncludedir = @yncludedir@/lilo

ynclude_DATA =		\
	io.ycp		\
	ui.ycp		\
	routines.ycp	\
	misc.ycp	\
	texts.ycp	\
	widgets.ycp	\
	helps.ycp	\
	scan.ycp

config_DATA = lilo.y2cc

module_DATA = Lilo.ycp

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(config_DATA) $(module_DATA)
