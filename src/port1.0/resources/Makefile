SUBDIR=		package sitelists
INSTALLDIR=	${DESTDIR}${datadir}/darwinports/resources/port1.0/
RSRCS=

include ../../../Mk/dports.subdir.mk
include ../../../Mk/dports.autoconf.mk

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} ${INSTALLDIR}
#	$(SILENT)set -x; for file in ${RSRCS}; do \
#		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
#	done
