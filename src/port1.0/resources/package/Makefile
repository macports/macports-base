PREFIX?=	/opt/local
INSTALLDIR=	${PREFIX}/share/darwinports/resources/port1.0/package
DSTUSR?=	root
DSTGRP?=	wheel

RSRCS=		background.tiff

all:

clean:

install:
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${RSRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
