MAN1=		port.1
INSTALLDIR=	${DESTDIR}${PREFIX}

include ../../Mk/dports.mk

mkdirs:
	cat ../../doc/prefix.mtree | sed -e "s/uname=UNAME/uname=${DSTUSR}/" | \
	sed -e "s/gname=GNAME/gname=${DSTGRP}/" | \
	mtree -U -d -e -p ${INSTALLDIR} > /dev/null

all:

clean:

distclean: clean

install: mkdirs
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 port.1 ${INSTALLDIR}/man/man1
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 port.tcl ${INSTALLDIR}/bin/port
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 portall.tcl ${INSTALLDIR}/bin/portall
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 portindex.tcl ${INSTALLDIR}/bin/portindex
