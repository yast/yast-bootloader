#
# Makefile.am for y2a_lilo/testsuite
#

SUBDIRS	= config lib ag_liloconf.test tests

AM_CXXFLAGS = -DY2LOG=\"agent-lilo\"

PACKAGE = ag_liloconf
AUTOMAKE_OPTIONS = dejagnu

INCLUDES = -I$(includedir)

noinst_PROGRAMS = runag_liloconf
runag_liloconf_SOURCES = runag_liloconf.cc

runag_liloconf_LDADD = -lscr -ly2 -lycp
runag_liloconf_LDFLAGS = -L$(libdir)	\
	-Xlinker --whole-archive	\
	$(plugindir)/libpy2stdio.la	\
	$(plugindir)/libpy2script.la	\
	$(srcdir)/../src/libpy2ag_liloconf.la	\
	-Xlinker --no-whole-archive

