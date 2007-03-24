INSTALLDIR=	${DESTDIR}${datadir}/darwinports/Tcl/registry1.0

SRCS= registry.tcl registry_autoconf.tcl receipt_flat.tcl receipt_sqlite.tcl portimage.tcl portuninstall.tcl

include ../../Mk/dports.autoconf.mk

all::

clean::

distclean:: clean
	rm -f registry_autoconf.tcl

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	$(SILENT) $(TCLSH) ../pkg_mkindex.tcl ${INSTALLDIR}

test::
