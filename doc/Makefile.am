#
# Makefile.am for y2c_lilo/doc
#

SUBDIRS = autodocs

htmldir = $(docdir)
pdfdir = $(docdir)
pngdir = $(docdir)

html_DATA = readme.mbr #bootloader.html
pdf_DATA = #bootloader.pdf
png_DATA = #$(wildcard *.png)

#bootloader.html:
#	db2html --nochunks bootloader.xml >bootloader.html

#bootloader.pdf:
#	db2pdf bootloader.xml

#%.png: %.dia
#	dia -n -e $@ $< 

#dias := $(wildcard *.dia)
#pngs := $(dias:%.dia=%.png)

#distdir-local: bootloader.html bootloader.pdf $(pngs)

EXTRA_DIST = $(html_DATA) $(pdf_DATA) $(png_DATA)

