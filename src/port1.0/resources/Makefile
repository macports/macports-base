SUBDIR=		package fetch group
INSTALLDIR=	${DESTDIR}${datadir}/macports/resources/port1.0/

include ../../../Mk/macports.subdir.mk
include ../../../Mk/macports.autoconf.mk

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}

