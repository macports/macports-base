SUBDIR=		package

PREFIX?=	/opt/local
INSTALLDIR=	${DESTROOT}${PREFIX}/share/darwinports/resources/port1.0/
DSTUSR?=	root
DSTGRP?=	wheel

RSRCS=

install::
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${RSRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done

include ../../../Mk/dports.subdir.mk
