PREFIX?=	/opt/local
MAN1=		port.1
DSTUSR?=	root
DSTGRP?=	wheel

port.1.gz: port.1
	gzip -cn port.1 > port.1.gz

all: port.1.gz

clean:
	rm -f port.1.gz

mkdirs:
	mkdir -p ${PREFIX}/bin
	mkdir -p ${PREFIX}/man/man1

install: mkdirs
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 port.1.gz ${PREFIX}/man/man1
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 port.tcl ${PREFIX}/bin/port
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 portall.tcl ${PREFIX}/bin/portall
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 555 portindex.tcl ${PREFIX}/bin/portindex
