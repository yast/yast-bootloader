#
# Makefile.am for yast2 agent
#

SUBDIRS = src conf doc testsuite

EXTRA_DIST = COPYRIGHT.english COPYRIGHT.french COPYRIGHT.german \
	VERSION README MAINTAINER RPMNAME $(RPMNAME).spec.in

AUTOMAKE_OPTIONS = foreign dist-bzip2

VERSION = $(shell cat $(srcdir)/VERSION)
RPMNAME = $(shell cat $(srcdir)/RPMNAME)

$(RPMNAME)-$(VERSION).tar.bz2: dist-bzip2

CLEANFILES = $(RPMNAME).kdoc
MAINTAINERCLEANFILES = package/$(RPMNAME)-*.tar.bz2 package/$(RPMNAME).spec

package: $(RPMNAME)-$(VERSION).tar.bz2
	rm -f package/$(RPMNAME)-*.tar.bz2
	mv $< package
