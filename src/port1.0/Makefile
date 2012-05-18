INSTALLDIR=	${DESTDIR}${datadir}/macports/Tcl/port1.0

SRCS=	port.tcl portchecksum.tcl portconfigure.tcl portextract.tcl	    \
	portfetch.tcl portmain.tcl portbuild.tcl portpatch.tcl portutil.tcl \
	portinstall.tcl portuninstall.tcl portdepends.tcl portdestroot.tcl \
	portlint.tcl portclean.tcl porttest.tcl portactivate.tcl \
	portdeactivate.tcl portsubmit.tcl port_autoconf.tcl portstartupitem.tcl \
	porttrace.tcl portlivecheck.tcl portdistcheck.tcl portmirror.tcl \
	portload.tcl portunload.tcl portdistfiles.tcl fetch_common.tcl

include ../../Mk/macports.subdir.mk
include ../../Mk/macports.autoconf.mk

.PHONY: test

all:: pkgIndex.tcl

pkgIndex.tcl: $(SRCS)
	$(SILENT) ../pkg_mkindex.sh . || ( rm -rf $@ && exit 1 )

clean::
	rm -f pkgIndex.tcl

distclean:: clean
	rm -f port_autoconf.tcl

install:: all
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 pkgIndex.tcl ${INSTALLDIR}

test::
	${TCLSH} tests/portutil.tcl ${macports_tcl_dir}
	${TCLSH} tests/portdestroot.tcl ${macports_tcl_dir}
	${TCLSH} tests/portfetch.tcl ${macports_tcl_dir}
