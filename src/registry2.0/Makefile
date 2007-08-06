OBJS=       registry.o util.o sql.o \
			creg.o centry.o \
			entry.o entryobj.o
			#graph.o graphobj.o
SHLIB_NAME= registry${SHLIB_SUFFIX}
INSTALLDIR= ${DESTDIR}${datadir}/macports/Tcl/registry2.0
export MACOSX_DEPLOYMENT_TARGET=10.3

include ../../Mk/macports.autoconf.mk
include ../../Mk/macports.tea.mk

.PHONY: test

test:: ${SHLIB_NAME}
	${TCLSH} tests/entry.tcl ${SHLIB_NAME}
