#
# Makefile.am for nis-client/agent-ypserv/src
#

AM_CXXFLAGS = -DY2LOG=\"agent-ypserv\" -I/usr/include/tirpc

noinst_LTLIBRARIES = libFindYpserv.la

libFindYpserv_la_SOURCES = FindYpserv.cc FindYpserv.h
libFindYpserv_la_LIBADD = -lnsl -ltirpc

plugin_LTLIBRARIES = libpy2ag_ypserv.la

libpy2ag_ypserv_la_SOURCES =			\
	Y2CCYpservAgent.cc			\
	YpservAgent.cc YpservAgent.h

libpy2ag_ypserv_la_LDFLAGS = -version-info 2:0
libpy2ag_ypserv_la_LIBADD = @AGENT_LIBADD@ libFindYpserv.la

# this program is for quick command-line testing
noinst_PROGRAMS = findypserv
findypserv_SOURCES =				\
	findypserv.cc

findypserv_LDADD = libFindYpserv.la

INCLUDES =					\
	-I$(includedir)
