SRCS=		darwinports.tcl darwinports_dlist.tcl darwinports_autoconf.tcl
OBJS=		darwinports.o portconf.o session.o util.o
SHLIB_NAME=	Darwinports${SHLIB_SUFFIX}

INSTALLDIR=	${DESTDIR}${TCL_PACKAGE_DIR}/darwinports1.0
DARWIN_OLD_PKGINDEX=	${DESTDIR}${TCL_PACKAGE_DIR}/8.3/darwinports1.0/pkgIndex.tcl

include ../../Mk/dports.autoconf.mk
include ../../Mk/dports.tea.mk

all::

clean::

distclean:: clean
	rm -f darwinports_autoconf.tcl;

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m 775 ${INSTALLDIR}

	$(SILENT) set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}/$$file; \
	done

	$(SILENT) ../pkg_mkindex.tcl ${INSTALLDIR}

#	XXX Prior installations of dports on Darwin installed darwinports1.0 
#	in a version-specific Tcl path

	$(SILENT) echo "/System/Library/Tcl" | grep "^/System/Library/Tcl" >/dev/null; \
	    if test $$? -eq 0; then \
		if test -f ${DARWIN_OLD_PKGINDEX}; then \
			set -x; \
			rm ${DARWIN_OLD_PKGINDEX}; \
		fi \
	    fi
