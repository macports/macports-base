SRCS=		darwinports.tcl darwinports_dlist.tcl
INSTALLDIR=	${TCL_PACKAGE_DIR}/darwinports1.0

include ../../Mk/dports.mk
include ../../Mk/dports.autoconf.mk

all:

clean:

distclean: clean

install:
	@mkdir -p ${INSTALLDIR}
	@set -x; for file in ${SRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	@../pkg_mkindex.tcl ${INSTALLDIR}
