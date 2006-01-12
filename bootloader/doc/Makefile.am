#
# Makefile.am for y2c_lilo/doc
#

SUBDIRS = autodocs

htmldir = $(docdir)

dias := $(wildcard *.dia)
pngs := $(dias:%.dia=%.png)
xmls := $(wildcard *.xml)

diagrams = \
	$(pngs)	\
	$(dias)


bootloader.html: $(xmls)
	db2html --nochunks bootloader.xml >bootloader.html

#bootloader.pdf: $(xmls)
#	db2pdf bootloader.xml

%.png: %.dia
	dia -n -e $@ $< 

#$(diagrams) bootloader.html

