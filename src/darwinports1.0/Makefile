SRCS=		darwinports.tcl darwinports_dlist.tcl

all:

clean:

install:
	@mkdir -p ${DESTDIR}`../../scripts/tcldir.sh`
	@set -x; for file in ${SRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${DESTDIR}`../../scripts/tcldir.sh`; \
	done
	@../pkg_mkindex.tcl ${DESTDIR}`../../scripts/tcldir.sh`

include ../../Mk/dports.mk
