INSTALLDIR=	${DESTDIR}${datadir}/darwinports/Tcl/port1.0

SRCS=	port.tcl portchecksum.tcl portconfigure.tcl portextract.tcl	    \
	portfetch.tcl portmain.tcl portbuild.tcl portpatch.tcl portutil.tcl \
	portinstall.tcl portdepends.tcl portdestroot.tcl \
        portclean.tcl porttest.tcl portactivate.tcl portsubmit.tcl \
	port_autoconf.tcl portstartupitem.tcl porttrace.tcl portlivecheck.tcl \
	portdistcheck.tcl portmirror.tcl

SUBDIR=		resources

include ../../Mk/dports.subdir.mk
include ../../Mk/dports.autoconf.mk

.PHONY: test

all::

clean::

distclean::
	rm -f port_autoconf.tcl

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	$(SILENT) $(TCLSH) ../pkg_mkindex.tcl ${INSTALLDIR}

test::
	${TCLSH} tests/portutil.tcl
