#
# Makefile.am for y2a_lilo/src
#

plugin_LTLIBRARIES = libpy2ag_liloconf.la
noinst_LTLIBRARIES = liby2ag_liloconf.la

liby2ag_liloconf_la_SOURCES =		\
	LiloAgent.cc	LiloAgent.h	\
	LiloFile.cc	LiloFile.h	\
	LiloSection.cc	LiloSection.h	\
	OptTypes.cc	OptTypes.h
liby2ag_liloconf_la_LDFLAGS = -version-info 2:0

libpy2ag_liloconf_la_SOURCES =				\
	$(liby2ag_liloconf_la_SOURCES)			\
	Y2CCLiloConf.cc         Y2CCLiloConf.h		\
	Y2LiloConfComponent.cc  Y2LiloConfComponent.h
libpy2ag_liloconf_la_LDFLAGS = -version-info 2:0

INCLUDES = -I$(includedir)

