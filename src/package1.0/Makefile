INSTALLDIR=	${DESTDIR}${datadir}/macports/Tcl/package1.0

SRCS=	package.tcl portdmg.tcl portmpkg.tcl portpkg.tcl portrpmpackage.tcl \
	portdpkg.tcl portunarchive.tcl portarchive.tcl

include ../../Mk/macports.autoconf.mk

all::

clean::

distclean::

test::

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	$(SILENT) $(TCLSH) ../pkg_mkindex.tcl ${INSTALLDIR}
