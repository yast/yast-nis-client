#
# Makefile.am for y2c_nis/agents
#
# $Id$
#

agentdir = $(YAST2DIR)/servers_non_y2
scrconfdir = $(YAST2DIR)/scrconf

agent_SCRIPTS = ag_yp_conf

scrconf_DATA = cfg_ypbind.scr yp_conf.scr

TESTS = test-ypconf
testdata = test-ypconf-i.in test-ypconf-i.out

EXTRA_DIST = $(agent_SCRIPTS) $(scrconf_DATA) $(TESTS) $(testdata)
