SRCS=		macports.tcl macports_dlist.tcl macports_util.tcl \
		macports_autoconf.tcl macports_index.tcl macports_fastload.tcl
OBJS=		macports.o portconf.o session.o util.o
SHLIB_NAME=	MacPorts${SHLIB_SUFFIX}

INSTALLDIR=	${DESTDIR}${TCL_PACKAGE_DIR}/macports1.0

include ../../Mk/macports.autoconf.mk
include ../../Mk/macports.tea.mk

test::

distclean:: clean
	rm -f macports_autoconf.tcl macports_fastload.tcl ${SHLIB_NAME}

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}

	$(SILENT) set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}/$$file; \
	done

	echo "${TCL_PACKAGE_DIR}" > ${DESTDIR}${prefix}/var/macports/.tclpackage

	$(SILENT) $(TCLSH) ../pkg_mkindex.tcl ${INSTALLDIR}
