MAN1=		port.1
INSTALLDIR=	${DESTDIR}${prefix}
TOPSRCDIR=	../..

include ../../Mk/dports.autoconf.mk

mkdirs:
	cat ../../doc/prefix.mtree | $(MTREE) -U -d -e -p ${INSTALLDIR} > /dev/null

all:

clean:

distclean: clean
	rm -f port portall portindex

install: mkdirs
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m 775 ${INSTALLDIR}/man/man1
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 port.1 ${INSTALLDIR}/man/man1
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m 775 ${INSTALLDIR}/bin
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 port ${INSTALLDIR}/bin/port
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 portall ${INSTALLDIR}/bin/portall
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 portindex ${INSTALLDIR}/bin/portindex
