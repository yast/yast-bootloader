#
# Makefile.am for y2c_lilo/src
#

clientsdir = $(YAST2DIR)/clients
yncludedir = $(YAST2DIR)/include/lilo
menudir = $(YAST2DIR)/menuentries
modulesdir = $(YAST2DIR)/modules

clients_DATA =		\
	lilo.ycp	\
	lilo_write.ycp	\
	lilo_auto.ycp

ynclude_DATA =		\
	io.ycp		\
	ui.ycp		\
	routines.ycp	\
	texts.ycp	\
	widgets.ycp	\
	helps.ycp	\
	scan.ycp	

menu_DATA = menuentry_lilo.y2cc

modules_DATA = Lilo.ycp

EXTRA_DIST = $(clients_DATA) $(ynclude_DATA) $(menu_DATA) $(modules_DATA)
