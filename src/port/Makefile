MAN1=		port.1
INSTALLDIR=	${DESTDIR}${PREFIX}

mkdirs:
	cat ../../doc/prefix.mtree | sed -e "s/uname=root/uname=${DSTUSR}/" | \
	sed -e "s/gname=admin/gname=${DSTGRP}/" | \
	mtree -U -d -e -p ${INSTALLDIR} > /dev/null

all:

clean:

install: mkdirs
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 port.1 ${INSTALLDIR}/man/man1
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 port.tcl ${INSTALLDIR}/bin/port
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 portall.tcl ${INSTALLDIR}/bin/portall
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 portindex.tcl ${INSTALLDIR}/bin/portindex

include ../../Mk/dports.mk
