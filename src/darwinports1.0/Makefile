SRCS=		darwinports.tcl darwinports_dlist.tcl
INSTALLDIR=	${TCL_PACKAGE_DIR}/darwinports1.0
DARWIN_OLD_PKGINDEX=${TCL_PACKAGE_DIR}/8.3/darwinports1.0/pkgIndex.tcl

include ../../Mk/dports.autoconf.mk

all:

clean:

distclean: clean

install:
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	$(SILENT)../pkg_mkindex.tcl ${INSTALLDIR}
# XXX Prior installations of dports on Darwin installed darwinports1.0 in a version-specific Tcl path
	$(SILENT)if test ${TCL_PACKAGE_DIR} -ef "/System/Library/Tcl" ; then \
		if test -f ${DARWIN_OLD_PKGINDEX}; then \
			set -x; \
			rm ${DARWIN_OLD_PKGINDEX}; \
		fi \
	fi
