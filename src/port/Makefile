MAN1=		port.1
INSTALLDIR=	${DESTDIR}${prefix}

include ../../Mk/dports.autoconf.mk

mkdirs:
	cat ../../doc/prefix.mtree | mtree -U -d -e -p ${INSTALLDIR} > /dev/null

all:

clean:

distclean: clean

install: mkdirs
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} ${INSTALLDIR}/man/man1
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 port.1 ${INSTALLDIR}/man/man1
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} ${INSTALLDIR}/bin
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 port.tcl ${INSTALLDIR}/bin/port
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 portall.tcl ${INSTALLDIR}/bin/portall
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 portindex.tcl ${INSTALLDIR}/bin/portindex
