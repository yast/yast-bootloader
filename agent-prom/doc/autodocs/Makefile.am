#
# Makefile.am for y2a_prom/doc/autodocs
#

docdir = @DOCDIR@
htmldir = $(docdir)/autodocs

html_DATA =				\
        PromAgent.html               \
        Y2CCPromAgent.html           \
        Y2PromAgentComponent.html    \
	heir.html			\
	index.html

EXTRA_DIST = $(html_DATA)

CLEANFILES = $(html_DATA)

$(filter-out index.html, $(html_DATA)): index.html
index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src && @YAST2DIR@/bin/ydoc @RPMNAME@ *.h
	mv -f $(srcdir)/../../src/*.html .
