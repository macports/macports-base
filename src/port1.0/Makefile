INSTALLDIR=	${DESTDIR}${datadir}/darwinports/Tcl/port1.0

SRCS= port.tcl portchecksum.tcl portconfigure.tcl portextract.tcl	    \
	portfetch.tcl portmain.tcl portbuild.tcl portpatch.tcl portutil.tcl \
	portinstall.tcl portdepends.tcl portinstall.tcl portuninstall.tcl   \
	portdepends.tcl portclean.tcl portpackage.tcl portcontents.tcl	    \
	portmpkg.tcl portrpmpackage.tcl

SUBDIR=		resources

include ../../Mk/dports.subdir.mk
include ../../Mk/dports.autoconf.mk

all::

clean::

distclean:: clean

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	$(SILENT)../pkg_mkindex.tcl ${INSTALLDIR}
