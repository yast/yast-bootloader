#
# Makefile.am for bootloader/agent-lilo/doc/autodocs
#

htmldir = $(docdir)/autodocs

html_DATA = index.html $(wildcard *.html)
CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.h
	( cd $(srcdir)/../../src && @ybindir@/ydoc agent-lilo *.h )
	mv -f $(srcdir)/../../src/*.html .
