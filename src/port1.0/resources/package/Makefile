INSTALLDIR=	${DESTDIR}${datadir}/darwinports/resources/port1.0/package
RSRCS=		background.tiff

include ../../../../Mk/dports.autoconf.mk

all:

clean:

distclean:

test:

install:
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${RSRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
