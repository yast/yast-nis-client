# Makefile.am for source/nis-client/src

myyncludedir = $(yncludedir)/nis

client_DATA =		\
	nis.ycp		\
	nis-client.ycp	\
	nis_auto.ycp

myynclude_DATA =	\
	ui.ycp

module_DATA =		\
	Nis.ycp

config_DATA = nis.y2cc

desktop_DATA = nis.desktop

EXTRA_DIST = $(client_DATA) $(myynclude_DATA) $(module_DATA) $(config_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
