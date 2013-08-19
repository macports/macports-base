SRCS=		macports.tcl macports_dlist.tcl macports_util.tcl \
		macports_autoconf.tcl macports_fastload.tcl
OBJS=		macports.o get_systemconfiguration_proxies.o sysctl.o
SHLIB_NAME=	MacPorts${SHLIB_SUFFIX}

INSTALLDIR=	${DESTDIR}${datadir}/macports/Tcl/macports1.0
INSTALLPKGLINK=	${TCL_PACKAGE_DIR}/macports1.0

include ../../Mk/macports.autoconf.mk
include ../../Mk/macports.tea.mk

ifeq ($(OBJC_RUNTIME), APPLE_RUNTIME)
	LIBS+= -framework CoreFoundation -framework SystemConfiguration
endif

pkgIndex.tcl: $(SRCS)

test::
	${TCLSH} tests/macports_dlist.tcl
	${TCLSH} tests/macports_util.tcl

distclean:: clean
	rm -f macports_autoconf.tcl macports_fastload.tcl ${SHLIB_NAME}

install:: all
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}

	$(SILENT) set -x; for file in ${SRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}/$$file; \
	done

	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 pkgIndex.tcl ${INSTALLDIR}

	echo "${TCL_PACKAGE_DIR}" > ${DESTDIR}${prefix}/var/macports/.tclpackage
	if test -z "${DESTDIR}" -a "${INSTALLPKGLINK}" != "${INSTALLDIR}"; then \
		if test ! -L "${INSTALLPKGLINK}"; then \
            if test ! -e "${TCL_PACKAGE_DIR}"; then \
                $(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} "${TCL_PACKAGE_DIR}" || true; \
            fi; \
            if test -d "${INSTALLPKGLINK}"; then \
                rm -vrf "${INSTALLPKGLINK}" || true; \
            fi; \
            if test ! -e "${INSTALLPKGLINK}"; then \
                ln -vs "${INSTALLDIR}" "${INSTALLPKGLINK}" || true; \
            fi; \
        fi; \
	fi
