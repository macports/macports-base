INSTALLDIR=	${DESTDIR}${datadir}/darwinports/Tcl/package1.0

SRCS=	package.tcl portdmg.tcl portmpkg.tcl portpkg.tcl portrpmpackage.tcl \
	portdpkg.tcl

include ../../Mk/dports.autoconf.mk

all::

clean::

distclean::

test::

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m 775 ${DESTDIR}${datadir}/darwinports
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m 775 ${DESTDIR}${datadir}/darwinports/Tcl
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m 775 ${INSTALLDIR}
	$(SILENT)set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	$(SILENT) $(TCLSH) ../pkg_mkindex.tcl ${INSTALLDIR}
