INSTALLDIR=	${DESTDIR}${datadir}/darwinports/resources/port1.0/package
RSRCS=		background.tiff

include ../../../../Mk/dports.mk
include ../../../../Mk/dports.autoconf.mk

all:

clean:

distclean: clean

install:
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${RSRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
