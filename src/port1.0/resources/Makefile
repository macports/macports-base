SUBDIR=		package sitelists
INSTALLDIR=	${DESTDIR}${datadir}/darwinports/resources/port1.0/
RSRCS=

include ../../../Mk/dports.subdir.mk
include ../../../Mk/dports.autoconf.mk
include ../../../Mk/dports.mk

install::
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${RSRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
