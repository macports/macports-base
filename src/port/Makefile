PREFIX?=	/opt/local
MAN1=		port.1
DSTUSR?=	root
DSTGRP?=	wheel

mkdirs:
	mtree -U -f ../../doc/prefix.mtree -d -e -p ${PREFIX} > /dev/null

all:

install: mkdirs
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 port.1 ${PREFIX}/man/man1
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 port.tcl ${PREFIX}/bin/port
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 portall.tcl ${PREFIX}/bin/portall
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 portindex.tcl ${PREFIX}/bin/portindex
