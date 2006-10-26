# Makefile.am for source/nis-client/src

myyncludedir = $(yncludedir)/nis
rncdir =  $(schemadir)/autoyast/rnc

client_DATA =		\
	nis.ycp		\
	nis-client.ycp	\
	nis_auto.ycp

myynclude_DATA =	\
	ui.ycp

module_DATA =		\
	Nis.ycp

desktop_DATA = nis.desktop

rnc_DATA = nis.rnc

nis:
	ln -sf . $@
ycpchook = nis

EXTRA_DIST = $(client_DATA) $(myynclude_DATA) $(module_DATA) $(desktop_DATA) $(rnc_DATA)

include $(top_srcdir)/Makefile.am.common
