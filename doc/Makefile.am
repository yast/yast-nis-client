#
# Makefile.am for y2c_nis/doc
#
# $Id$
#

SUBDIRS = autodocs

htmldir = $(docdir)

screenshots = \
	$(wildcard nis*.png)

workflow.png: workflow.dia $(screenshots)
	dia --export=$@ $<
MAINTAINERCLEANFILES = workflow.png

html_DATA = index.html ypdomainname.txt workflow.dia workflow.png $(screenshots)
EXTRA_DIST = $(html_DATA)
