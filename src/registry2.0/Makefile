# $Id$

SRCS = registry_util.tcl portimage.tcl portuninstall.tcl
OBJS = registry.o util.o \
	entry.o entryobj.o
	#graph.o graphobj.o

SHLIB_NAME= registry${SHLIB_SUFFIX}
INSTALLDIR= ${DESTDIR}${datadir}/macports/Tcl/registry2.0
export MACOSX_DEPLOYMENT_TARGET=10.3

include ../../Mk/macports.autoconf.mk
include ../../Mk/macports.tea.mk

LIBS+=	../cregistry/cregistry.a ${SQLITE3_LIBS}

.PHONY: test

test:: ${SHLIB_NAME}
	${TCLSH} tests/entry.tcl ${SHLIB_NAME}
	${TCLSH} tests/depends.tcl ${SHLIB_NAME}

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 ${SHLIB_NAME} ${INSTALLDIR}
	$(SILENT) set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}/$$file; \
	done
	$(SILENT) $(TCLSH) ../pkg_mkindex.tcl ${INSTALLDIR}
