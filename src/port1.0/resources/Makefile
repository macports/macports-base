SUBDIR=		package

INSTALLDIR=	${DESTDIR}${PREFIX}/share/darwinports/resources/port1.0/

RSRCS=

install::
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${RSRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done

include ../../../Mk/dports.subdir.mk
include ../../../Mk/dports.mk
