INSTALLDIR=	${DESTDIR}${PREFIX}/share/darwinports/resources/port1.0/sitelists

RSRCS=		master_sites.tcl

all:

clean:

install:
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${RSRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done

include ../../../../Mk/dports.mk
