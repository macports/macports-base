INSTALLDIR=	${DESTDIR}${datadir}/macports/Tcl/package1.0

SRCS=	package.tcl portdmg.tcl portmdmg.tcl portmpkg.tcl portpkg.tcl \
	portrpm.tcl portsrpm.tcl portdpkg.tcl portunarchive.tcl \
	portarchivefetch.tcl

include ../../Mk/macports.autoconf.mk

all:: pkgIndex.tcl

pkgIndex.tcl: $(SRCS)
	$(SILENT) ../pkg_mkindex.sh .

clean::
	rm -f pkgIndex.tcl

distclean:: clean

test::

install:: all
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 pkgIndex.tcl ${INSTALLDIR}
