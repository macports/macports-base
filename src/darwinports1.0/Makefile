SRCS=		darwinports.tcl darwinports_dlist.tcl
INSTALLDIR=	${DESTDIR}`../../scripts/config.sh installdir`

all:

clean:

install:
	@mkdir -p ${INSTALLDIR}
	@set -x; for file in ${SRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	@../pkg_mkindex.tcl ${INSTALLDIR}

include ../../Mk/dports.mk
