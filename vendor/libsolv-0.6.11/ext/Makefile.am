libsolvext_sources = solv_xfopen.c testcase.c
libsolvext_headers = tools_util.h solv_xfopen.h testcase.h

lib_LTLIBRARIES = libsolvext.la
libsolvext_la_CPPFLAGS = -I$(srcdir)/../src -I../src
libsolvext_la_SOURCES = $(libsolvext_sources) $(libsolvext_headers)
