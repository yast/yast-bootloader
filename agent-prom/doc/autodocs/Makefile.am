#
# Makefile.am for bootloader/agent-prom/doc/autodocs
#

htmldir = $(docdir)/agent-prom/autodocs

html_DATA = index.html $(wildcard *.html)

CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src && @ybindir@/ydoc agent-prom *.h
	mv -f $(srcdir)/../../src/*.html .
