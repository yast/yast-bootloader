#
# Makefile.am for y2a_prom/doc/autodocs
#

htmldir = $(docdir)/autodocs

html_DATA =				\
	PromAgent.html			\
	heir.html			\
	index.html

EXTRA_DIST = $(html_DATA)

CLEANFILES = $(html_DATA)

$(filter-out index.html, $(html_DATA)): index.html
index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src && @ybindir@/ydoc @RPMNAME@ *.h
	mv -f $(srcdir)/../../src/*.html .
