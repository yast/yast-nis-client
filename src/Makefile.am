# Sources for nis-client

module_DATA = \
  modules/Nis.rb

client_DATA = \
  clients/nis.rb \
  clients/nis-client.rb \
  clients/nis_auto.rb

yncludedir = @yncludedir@/nis
ynclude_DATA = \
  include/nis/ui.rb

scrconf_DATA = \
  scrconf/ypserv.scr \
  scrconf/cfg_ypbind.scr \
  scrconf/yp_conf.scr \
  scrconf/etc_defaultdomain.scr

agent_SCRIPTS = \
  servers_non_y2/ag_yp_conf

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/nis.rnc

desktop_DATA = \
  desktop/org.opensuse.yast.NIS.desktop

scalabledir = @icondir@/hicolor/scalable/apps
scalable_DATA = \
  icons/hicolor/scalable/apps/yast-nis.svg

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(schemafiles_DATA) $(desktop_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
