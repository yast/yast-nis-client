#
# Makefile.am for y2c_nis/src
#
# $Id$
#

clientsdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/nis
modulesdir = $(YAST2DIR)/modules
menudir = $(YAST2DIR)/menuentries
autoinstdir = $(YAST2DIR)/autoinstall

clients_DATA =		\
	nis.ycp		\
	nis_auto.ycp	\
	nis_write.ycp

include_DATA =		\
	ui.ycp

modules_DATA =		\
	Nis.ycp

menu_DATA = menuentry_nis.y2cc
autoinst_DATA = autoinst_nis.conf

EXTRA_DIST = $(clients_DATA) $(include_DATA) $(modules_DATA) $(menu_DATA) $(autoinst_DATA)
