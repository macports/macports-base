INSTALLDIR=	${DESTDIR}${prefix}/share/darwinports/resources/port1.0/sitelists

RSRCS=		master_sites.tcl

include ../../../../Mk/dports.autoconf.mk

all:

clean:

distclean:

install:
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${RSRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
