#
# Makefile.am for y2a_prom/src
#


AM_CXXFLAGS = -Wall # -g # -pedantic # -W

plugindir = $(YAST2DIR)/plugin

plugin_LTLIBRARIES = libpy2ag_prom.la
noinst_LTLIBRARIES = liby2ag_prom.la

liby2ag_prom_la_SOURCES =                    \
	PromAgent.cc	prom.cc		\
	PromAgent.h	prom.h
liby2ag_prom_la_LDFLAGS = -version-info 2:0

libpy2ag_prom_la_SOURCES =                           \
        $(liby2ag_prom_la_SOURCES)                   \
        Y2CCPromAgent.cc
libpy2ag_prom_la_LDFLAGS = -version-info 2:0

INCLUDES = -I$(includedir)

