# $Id$

SRCS = registry.tcl registry_autoconf.tcl registry_util.tcl receipt_flat.tcl receipt_sqlite.tcl portimage.tcl portuninstall.tcl
OBJS = registry.o util.o \
	entry.o entryobj.o \
	file.o fileobj.o \
	../cregistry/cregistry.a
	#graph.o graphobj.o

SHLIB_NAME= registry${SHLIB_SUFFIX}
INSTALLDIR= ${DESTDIR}${datadir}/macports/Tcl/registry2.0

include ../../Mk/macports.autoconf.mk
include ../../Mk/macports.tea.mk

pkgIndex.tcl: $(SRCS)

CFLAGS+=	${SQLITE3_CFLAGS}
LIBS+=	${SQLITE3_LIBS}
ifeq ($(shell uname), Darwin)
	SHLIB_LDFLAGS+= -install_name ${datadir}/macports/Tcl/registry2.0/${SHLIB_NAME}
endif

.PHONY: test

test:: ${SHLIB_NAME}
	${TCLSH} tests/entry.tcl ./${SHLIB_NAME}
	${TCLSH} tests/depends.tcl ./${SHLIB_NAME}

distclean:: clean
	rm -f registry_autoconf.tcl

install:: all
	[ ! -d $(DESTDIR)${datadir}/macports/Tcl/registry1.0 ] || rm -vrf $(DESTDIR)${datadir}/macports/Tcl/registry1.0
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 ${SHLIB_NAME} ${INSTALLDIR}
	$(SILENT) set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}/$$file; \
	done
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 pkgIndex.tcl ${INSTALLDIR}
