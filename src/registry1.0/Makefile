INSTALLDIR=	${DESTDIR}${datadir}/macports/Tcl/registry1.0

SRCS= registry.tcl registry_autoconf.tcl receipt_flat.tcl receipt_sqlite.tcl portimage.tcl portuninstall.tcl

include ../../Mk/macports.autoconf.mk

all:: pkgIndex.tcl

pkgIndex.tcl:
	$(SILENT) ../pkg_mkindex.sh .

clean::
	rm -f pkgIndex.tcl

distclean:: clean
	rm -f registry_autoconf.tcl

install:: all
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 pkgIndex.tcl ${INSTALLDIR}

test::
